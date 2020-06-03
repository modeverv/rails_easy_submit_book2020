# frozen_string_literal: true

class PostsController < ApplicationController
  before_action :set_post, only: %i[show edit update destroy view shot publish]

  $driver = nil

  def _get_driver
    return $driver unless $driver.blank?

    puts 'generate google instance'
    Selenium::WebDriver::Chrome::Service.driver_path = ENV.fetch('DRIVER_PATH') { '/usr/local/bin/chromedriver' }
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    # options.add_argument('--disable-gpu')
    options.add_argument('--hide-scrollbars')
    options.binary = ENV.fetch('CHROME_BIN') { '/usr/bin/google-chrome' }
    $driver = Selenium::WebDriver.for :chrome, options: options
    $driver
  end

  # GET /posts
  # GET /posts.json
  def index
    @posts = Post.all
  end

  # GET /posts/1
  # GET /posts/1.json
  def show; end

  def publish
    temp_file = _get_shot
    @media_urls = _send_to_twitter temp_file
  end

  def _send_to_twitter(temp_file)
    t = TwitterAPI::Client.new(
      consumer_key: ENV.fetch('CONSUMER_KEY'),
      consumer_secret: ENV.fetch('CONSUMER_SECRET'),
      token: ENV.fetch('TOKEN'),
      token_secret: ENV.fetch('TOKEN_SECRET')
    )
    image = File.open(temp_file.path, 'rb').read
    res = t.media_upload('media' => image)
    media_id = JSON.parse(res.body)['media_id_string']
    res = t.statuses_update(
      'status' => '',
      'media_ids' => media_id
    )
    status_id = JSON.parse(res.body)['id_str']
    res = t.statuses_show_id('id' => status_id)
    tweet = JSON.parse(res.body)
    url = ''
    display_url = ''
    tweet['extended_entities']['media'].each do |media|
      url = media['media_url']
      display_url = media['display_url']
      break
    end
    [url, display_url]
  end

  def view
    @view = true
    render 'show'
  end

  def _get_shot
    driver = _get_driver
    driver.get view_url(@post)
    width = driver.execute_script('return document.body.scrollWidth')
    height = driver.execute_script('return document.body.scrollHeight + 300')
    driver.manage.window.resize_to(width, height)
    driver.manage.window.maximize
    sleep 5 # required waiting for page loading
    file = Tempfile.new(["template_#{@post.id}", '.png'], 'tmp',
                        encoding: 'ascii-8bit')
    driver.save_screenshot file.path
    file
  end

  def shot
    begin
      file = _get_shot
    rescue StandardError => e
      p e
      $driver = nil
      shot
    end
    # file = kit.to_file(Rails.root + 'public/pngs/' + 'screenshot.png')
    send_file(file.path, filename: 'screenshot.png', type: 'image/png', disposition: 'attachment', streaming: 'true')
  end

  # GET /posts/new
  def new
    @post = Post.new
  end

  # GET /posts/1/edit
  def edit; end

  # POST /posts
  # POST /posts.json
  def create
    @post = Post.new(post_params)
    @post.change_key = post_params[:change_key_virtual]
    respond_to do |format|
      if @post.save
        format.html { redirect_to @post, notice: '作成完了' }
        format.json { render :show, status: :created, location: @post }
      else
        format.html { render :new }
        format.json { render json: @post.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /posts/1
  # PATCH/PUT /posts/1.json
  def update
    logger.warn(@post.inspect)
    @post.change_key = post_params[:change_key_virtual] if @post.change_key.blank?
    if post_params[:change_key_virtual] != @post.change_key
      respond_to do |format|
        format.html { redirect_to @post, notice: 'キーが一致しないから更新できぬ' }
      end
      return
    end
    @post.change_key = post_params[:change_key_virtual]
    respond_to do |format|
      if @post.update(post_params)
        format.html { redirect_to @post, notice: '更新完了' }
        format.json { render :show, status: :ok, location: @post }
      else
        format.html { render :edit }
        format.json { render json: @post.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /posts/1
  # DELETE /posts/1.json
  def destroy
    @post.destroy
    respond_to do |format|
      format.html { redirect_to posts_url, notice: '削除完了' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_post
    @post = Post.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def post_params
    params.require(:post).permit(:title, :content, :author, :change_key_virtual)
  end
end
