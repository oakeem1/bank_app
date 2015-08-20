class Account
	include DataMapper::Resource
	property :id, Serial, :key => true
	property :type, String, :required => true
	property :balance, Float, :default  => 0.00
	belongs_to :user
end
