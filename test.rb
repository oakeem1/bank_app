require 'rubygems'
require 'data_mapper'
require 'dm-sqlite-adapter'
require 'bcrypt'
require 'sinatra'
require "tilt/erb"
require 'sinatra/base'
require 'sinatra/flash'
require 'warden'
require "sinatra/reloader"
require 'rack'
require 'bundler'
# Bundler.require

# load the Database, User and Account model
DataMapper.setup(:default, "sqlite://#{Dir.pwd}/acc.db")
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

class Account
  include DataMapper::Resource
  property :id, Serial, :key => true
  property :type, String, :required => true
  property :balance, Float, :default  => 0.00
  belongs_to :user
end

DataMapper.finalize
DataMapper.auto_upgrade!

if User.count == 0
  @user = User.create(username: "admin")
  @user.password = "admin"
  @user.save
end

Warden::Strategies.add(:password) do
    def valid?
      params['user']&&params['user']['username'] && params['user']['password']
    end

    def authenticate!
      user = User.first(username: params['user']['username'])
      if user.nil?
        throw(:warden, message: "The username you entered does not exist.")
      elsif user.authenticate(params['user']['password'])
        success!(user)
      else
        throw(:warden, message: "The username and password combination ")
      end
    end
end

class BankApp < Sinatra::Base
  enable :sessions
  register Sinatra::Flash
  set :session_secret, "supersecret"

  get '/' do
    erb :index
  end

  get '/login' do
    erb :login
  end

  post '/login' do
    # env['warden'].authenticate!
    erb :index
    # flash[:success] = env['warden'].message

    # if session[:return_to].nil?
      # redirect '/'
    # else
    #   redirect session[:return_to]
    # end
  end

  get '/signup' do
    erb :signup
  end

  post '/signup' do
    User.create(:username => params[:username], :password => params[:password])
    redirect '/'
  end

  get '/auth/logout' do
    env['warden'].raw_session.inspect
    env['warden'].logout
    flash[:success] = 'Successfully logged out'
    redirect '/'
  end

  post '/auth/unauthenticated' do
    session[:return_to] = env['warden.options'][:attempted_path]
    puts env['warden.options'][:attempted_path]
    flash[:error] = env['warden'].message || "You must log in"
    redirect '/auth/login'
  end

  get '/protected' do
    env['warden'].authenticate!
    @current_user = env['warden'].user
    erb :protected
  end


  # Warden configuration code  
  use Rack::Session::Cookie

  use Warden::Manager do |manager|
    manager.serialize_into_session {|user| user.id}
    manager.serialize_from_session {|id| User.get(id)}
    manager.scope_defaults :default,
      # "strategies" is an array of named methods with which to
      # attempt authentication. We have to define this later.
      strategies: [:password],
      # The action is a route to send the user to when
      # warden.authenticate! returns a false answer. We'll show
      # this route below.
      action: 'auth/unauthenticated'
    # When a user tries to log in and cannot, this specifies the
    # app to send the user to.
    manager.failure_app = self
  end

  Warden::Manager.before_failure do |env,opts|
    env['REQUEST_METHOD'] = 'POST'
  end

  def warden_handler
    env['warden']
  end

  def check_authentication
    unless warden_handler.authenticated?
      redirect '/login'
    end
  end

  def current_user
    warden_handler.user
  end
  BankApp.new
 run! if app_file == $0
end
# # BankApp = Rack::Builder.new do
# #   use Rack::Reloader, 0
# #   use Rack::ContentLength
# #   app = proc do |env|
# #     [ 200, {'Content-Type' => 'text/plain'}, ["b"] ]
# #   end
# #   run app
# end