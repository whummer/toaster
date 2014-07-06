
require "active_record"

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  begin
    devise :database_authenticatable, :registerable,
           :recoverable, :rememberable, :trackable, :validatable
  rescue
    # devise not available in non-rails mode
  end

  def self.set_current_user(user)
    @@current_user = user
  end
  def self.get_current_user()
    @@current_user
  end
  def self.get_local_user()
    u = User.find(
      :email => "local@localhost"
    )
    return u if u
    u = User.create(
      :email => "local@localhost",
      :encrypted_password => ""
    )
    u.save
    return u
  end
end
