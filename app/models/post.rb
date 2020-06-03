class Post < ApplicationRecord
    has_rich_text :content
    attr_accessor :change_key_virtual
    validates :title, presence: true
    validates :author, presence: true
    validates :content, presence: true
end
