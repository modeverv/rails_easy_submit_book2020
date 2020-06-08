# frozen_string_literal: true

class PostsController < ApplicationController
  before_action :set_post, only: %i[show edit update destroy view shot publish]

  $driver = nil

  def _get_driver
    return $driver unless $driver.blank?
    logger.info('generate google instance')
    Selenium::WebDriver::Chrome::Service.driver_path = ENV.fetch('DRIVER_PATH') { '/usr/local/bin/chromedriver' }
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-gpu')
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
    #temp_file = "#{Dir.pwd}/public/post_#{@post.id}.png"
    @media_urls = _send_to_twitter temp_file
  end

  def _send_to_twitter(temp_file)
    t = TwitterAPI::Client.new(
      consumer_key: ENV.fetch('CONSUMER_KEY'),
      consumer_secret: ENV.fetch('CONSUMER_SECRET'),
      token: ENV.fetch('TOKEN'),
      token_secret: ENV.fetch('TOKEN_SECRET')
    )
    image = Magick::Image.read(temp_file).first    
    width = image.columns
    height = image.rows
    logger.info(height)
    count = (height / 4000.0).round
    count = (height / 1200.0).round
    is_ommited = false
    is_ommited = true if count > 4
    count = 4 if count > 4
    logger.info(count)
    images = []
    count.times do |i|
      logger.info(i) # 0,1,2
      height_start = 0 + (4000 * i)
      height_start = 0 + (1200 * i)      
      length = 1200
      length = height - height_start if height_start + length > height
      logger.info(height_start)
      logger.info(length)
      images << image.crop(0, height_start, width, length)
    end
    if is_ommited
      _target_image = images.last
      width = _target_image.columns
      height = _target_image.rows
      target_image = Magick::Image.new(width, height) do |image|
        image.background_color= "Transparent"
      end
      font = "#{Dir.pwd}/public/ipaexg.ttf"
      str = "続きはリンク先で！"
      draw = Magick::Draw.new 
      draw.annotate(target_image, 0, 0, 10, 10, str) do
        self.font      = font                      # フォント
        self.fill      = 'blue'                   # フォント塗りつぶし色(白)
        self.stroke    = 'transparent'             # フォント縁取り色(透過)
        self.pointsize = 64                        # フォントサイズ(16pt)
        self.gravity   = Magick::SouthEastGravity  # 描画基準位置(右下)
      end
      target_image = _target_image.composite(target_image, 0, 0, Magick::OverCompositeOp)
      images[images.size - 1] = target_image
    end
    response = []
    temp_files = []
    images.each_with_index do |image, i|
      file = Tempfile.new(["tempfile_#{@post.id}_#{i}", '.png'], 'tmp',
      encoding: 'ascii-8bit')
      image.write(file.path)
      #image.write("#{Dir.pwd}/public/post_#{@post.id}_#{i}.png")
      temp_files << file
      #temp_files << "#{Dir.pwd}/public/post_#{@post.id}_#{i}.png"
    end
    media_ids = []
    temp_files.each do |temp_file|
      image = File.open(temp_file.path, 'rb').read
      #image = File.open(temp_file, 'rb').read
      res = t.media_upload('media' => image)
      logger.info(res.body)
      media_ids << JSON.parse(res.body)['media_id_string']
    end
    res = t.statuses_update(
      'status' => '#Twitter小説書きの支援ツール',
      'media_ids' => media_ids.join(",")
    )
    logger.info(res.body)
    status_id = JSON.parse(res.body)['id_str']
    res = t.statuses_show_id('id' => status_id)
    tweet = JSON.parse(res.body)
    tweet['extended_entities']['media'].each do |media|
      response << [media['media_url'],media['display_url']]
    end
    response
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
    sleep 20 # required waiting for page loading
    file = Tempfile.new(["tempfile_#{@post.id}", '.png'], 'tmp',
      encoding: 'ascii-8bit')
    #file = File.new();
    #driver.save_screenshot "#{Dir.pwd}/public/post_#{@post.id}.png"
    driver.save_screenshot file.path
    #logger.info(File.size("#{Dir.pwd}/public/s#{@post.id}.png"))
    logger.info(File.size(file.path))
    file.path
  end

  def shot
    begin
      file = _get_shot
    rescue StandardError => e
      logger.warn(e)
      $driver = nil
      shot
    end
    # file = kit.to_file(Rails.root + 'public/pngs/' + 'screenshot.png')
    send_file(file, filename: 'screenshot.png', type: 'image/png', disposition: 'attachment', streaming: 'true')
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
