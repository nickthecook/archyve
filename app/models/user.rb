class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable

  has_many :messages, as: :author, dependent: :destroy
  has_many :conversations, dependent: :destroy

  # TODO: make collection belong_to user and remove this
  def collections
    Collection.all
  end
end
