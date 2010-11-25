require 'digest'

class User
  include Mongoid::Document
  include Mongoid::Timestamps

  field :admin, :type => Boolean, :default => false
  field :salt
  field :encrypted_password
  field :email
  index :email, :unique => true
  field :name
  field :following_ids, :type => Array, :default => []

  attr_accessor :password, :updating_password
  attr_accessible :name, :email, :password, :password_confirmation, :admin

  references_many :microposts, :dependent => :destroy
#   references_many :following, :stored_as => :array, :inverse_of => :followed_by, :class_name => 'User' # :foreign_key => "following_id" #, :stored_as => :array, :inverse_of => :followed
#   references_many :following, :stored_as => :array, :inverse_of => :followed_by



  email_regex = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  validates :name, :presence => true,
                   :length => { :maximum => 50 }
  validates :email, :presence => true,
                    :format => { :with => email_regex },
                    :uniqueness => { :case_sensitive => false }
  validates :password, :presence     => true,
                       :confirmation => true,
                       :length       => { :within => 6..40 },
                       :if => :should_validate_password?

  before_save :encrypt_password

  # Return true if the user's password matches the submitted password.
  def has_password?(submitted_password)
    # Compare encrypted_password with the encrypted version of
    # submitted_password.
    encrypted_password == encrypt(submitted_password)
  end


  def self.authenticate(email, submitted_password)
    user = find :first, :conditions => {:email => email}
    return nil  if user.nil?
    return user if user.has_password?(submitted_password)
  end

  def self.authenticate_with_salt(id, cookie_salt)
    user = find(id)
    (user && user.salt == cookie_salt) ? user : nil
  rescue Mongoid::Errors::DocumentNotFound
    nil
  end

  def following
    User.where(:_id.in => self.following_ids)
  end

  def followers
    User.where(:following_ids => self.id)
  end

  def following?(followed)
    self.following_ids.include? followed.id
  end

  def follow!(followed)
    self.following_ids << followed.id
    self.save!
  end

  def unfollow!(followed)
    self.following_ids.delete followed.id
    self.save!
  end

  def feed
    Micropost.from_users_followed_by(self)
  end

  def should_validate_password?
    updating_password || new_record?
  end

  private

    def encrypt_password
      if should_validate_password?
        self.salt = make_salt if new_record?
        self.encrypted_password = encrypt(password)
      end
    end

    def encrypt(string)
      secure_hash("#{salt}--#{string}")
    end

    def make_salt
      secure_hash("#{Time.now.utc}--#{password}")
    end

    def secure_hash(string)
      Digest::SHA2.hexdigest(string)
    end
end
