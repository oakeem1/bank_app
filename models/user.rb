class User
  include DataMapper::Resource
  include BCrypt

  property :id, Serial, :key => true
  property :username, String, :length => 3..50
  property :password, BCryptHash
  has n, :accounts

  def authenticate(attempted_password)
    if self.password == attempted_password
      true
    else
      false
    end
  end
end
