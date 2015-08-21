require 'rubygems'
require 'data_mapper'
require 'dm-sqlite-adapter'
require 'bcrypt'
require 'sinatra'
require "tilt/erb"
require 'sinatra/base'
require 'sinatra/flash'
require "sinatra/reloader"
require 'rack'
# require 'bundler'
# Bundler.require

# load the Database, User and Account model
DataMapper.setup(:default, "sqlite://#{Dir.pwd}/acc.db")
class User
  include DataMapper::Resource
  include BCrypt

  property :id, Serial, :key => true
  property :username, String, :required => true, :unique =>true, :length => 3..50
  property :password, BCryptHash, :required => true
  has n, :accounts
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
  @user.password = "root"
  @user.save
end

class BankApp < Sinatra::Base
  enable :sessions
  register Sinatra::Flash
  set :session_secret, "supersecret"

  helpers do
    def login?
      if session[:username].nil?
        return false
      else
        return true
      end
    end

    def username
      return session[:username]
    end    
  end
  
  get '/back' do
   redirect back
  end

  get '/login' do
    erb :login
  end

  post '/login' do
    if User.count(:username => params[:username]) > 0
      user = User.first(:username => params[:username])
      if user[:password] == params[:password]
        session[:username] = params[:username]
        flash.keep
        flash[:success] = "You have successfully logged in!"
        redirect '/user_dashboard'
      else
          flash[:error] = "Login failed"
          redirect '/login'
      end
    else
      flash[:error] = "Login failed"
      redirect '/login'
    end
  end

  get '/user_dashboard' do
    if login?
      erb :user_dashboard
    else
      redirect '/login'
    end
  end

  get '/signup' do
    erb :signup
  end

  post '/signup' do
    User.create(:username => params[:username], :password => params[:password])
    session[:username] = params[:username]
    flash.keep
    flash[:info] = 'Thanks for signing up!'
    redirect '/user_dashboard'
  end

  get '/create_account' do
    if login?
      erb :create_account
    else
      redirect '/login'
    end
  end

  post '/create_account' do
    if login?
      user = User.first(:username => session[:username])
      Account.create(:type => params[:type], :balance => params[:balance], :user_id => user[:id])
        flash.keep
        flash.now[:success] = "The account was successfully created."
        redirect '/user_dashboard'
    else
      redirect '/login'
    end
  end

  get '/user_accounts' do
    if login?
      user = User.first(:username => session[:username])
      @account = user.accounts
      erb :user_accounts
    else
      redirect '/login'
    end
  end

  get '/deposit/:id' do
    if login?
      @account = Account.first(:id => params[:id])
      erb :deposit
    else
      redirect '/login'
    end
  end
  post '/deposit/:id' do
    if login?
      if params.has_key?("ok")
        account = Account.first(:id => params[:id])
        old_balance = account[:balance]
        new_balance = old_balance + params[:amount].to_f
        account.update(:balance => new_balance)
        flash.keep
        flash.now[:success] = "Your account has been credited."
        redirect '/user_dashboard'
      else
        redirect '/user_accounts'
      end
    else
      redirect '/login'
    end
  end

  get '/withdraw/:id' do
    if login?
      @account = Account.first(:id => params[:id])
      erb :withdraw
    else
      redirect '/login'
    end
  end

  post '/withdraw/:id' do
    if login?
      if params.has_key?("ok")
        account = Account.first(:id => params[:id])
        old_balance = account[:balance]
        if old_balance >= params[:amount].to_f
          new_balance = old_balance - params[:amount].to_f
          account.update(:balance => new_balance)
          flash.keep
          flash.now[:success] = "Your account has been debited."
          redirect '/user_dashboard'
        else
          flash.keep
          flash[:warning] = 'Account too low for transaction'
          redirect '/user_accounts'
        end
      else
        flash.keep
        flash[:info] = 'Transaction cancelled'
        redirect '/user_dashboard'
      end
    else
      flash.keep
      flash[:info] = 'You must Login to perform transactions'
      redirect '/login'
    end
  end

  get '/delete/:id' do
    if login?
      @account = Account.first(:id => params[:id])
      erb :delete
    else
      redirect '/login'
    end
  end

  delete '/delete/:id' do
    if login?
      if params.has_key?("ok")
        account = Account.first(:id => params[:id])
        account.destroy
        flash.keep
        flash[:success] = 'Account deleted'
        redirect '/user_dashboard'
      else
        flash.keep
        flash[:info] = 'Transaction cancelled'
        redirect '/user_dashboard'
      end
    else
      flash.keep
      flash[:info] = 'You must Login to perform transactions'
      redirect '/login'
    end
end


  get '/logout' do
    session[:username] = nil
    flash.keep
    flash[:success] = 'Successfully logged out'
    redirect '/'
  end

  BankApp.new
  run! if app_file == $0
end
