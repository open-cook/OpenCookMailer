# $KCODE = "UTF-8"
# encoding: UTF-8
# coding: UTF-8

require 'sass'
require 'base64'
require 'compass'
require 'coffee-script'

class MarkupTemplate < Padrino::Application
  register Padrino::Flash
  register Padrino::Mailer
  register Padrino::Helpers
  register Padrino::Rendering
  register CompassInitializer

  layout :layout

  begin
    set :delivery_method, :smtp => MAIL_SETTINGS
  rescue
    puts " = ." * 15
    puts " WARNING! Define MAIL_SETTINGS in lib/mail_settings.rb"
    puts " = ." * 15
  end

  helpers do
    def md5 str = ''
      Digest::MD5.hexdigest str.to_s
    end

    def email_image name, options = {}
      return image_tag(name, options) unless @is_mail
      options.merge!(:src => "cid:#{name}")
      tag :img, options
    end

    def partial name, options = {}
      parts = name.split '/'
      name  = parts.pop
      path  = [parts, "_#{name}"].join '/'
      haml path.to_sym, :locals => options[:locals], :layout => false
    end
  end

  # slider
  get '/slider' do
    haml :slider, layout: :slider_layout
  end

  # Pages
  get '/' do
    haml :index
  end

  get '/eye_timer' do
    haml :eye_timer
  end

  get '/about' do
    haml :about, :locals => { :name => 'Sinatra Markup App' }
  end

  get '/mail/letter' do
    @user_email = 'zykin-ilya@narod.ru'
    haml :"../mailers/letter", :layout => :mailer, :locals => { :is_mail => false }
  end

  # SEND MAIL
  before '/mail/send' do
    @@img_path = "#{Padrino.root}/public/images/"

    @@attachments = %w[
      open-cook/OK-BASE-LOGO.png
      open-cook/mixer.png

      open-cook/foodparty.png
      open-cook/2015.png
      open-cook/Anna.png
      open-cook/vote.png
      open-cook/win.png
    ]
  end

  post '/mail/send' do
    @is_mail = true

    addressers_1 = params[:emails].split(',').map(&:strip)
    addressers_2 = params[:emails_str].split("\n").map(&:strip)
    addressers = (addressers_1 + addressers_2).uniq

    subject = params[:subject]

    # LOG FILES NAMES
    FileUtils.mkdir_p "#{ Padrino.root }/log"

    log_name = "#{ Padrino.root }/log/#{Time.new.strftime("%Y-%m-%d-%H-%M")}"

    # LOGGING OPEN
    log_success = File.open "#{log_name}.success.log", 'w+'
    log_error   = File.open "#{log_name}.error.log",   'w+'
    log_enotice = File.open "#{log_name}.enotice.log", 'w+'

    addressers.each do |adresser|
      @user_email = adresser
      html_letter = haml(:"../mailers/letter", :locals => { :is_mail => true }, :layout => false)

      begin
        email do
          from     'mixer@open-cook.ru'
          to       adresser
          subject  subject
          via      :smtp
          provides :html
          html_part html_letter

          @@attachments.each_with_index do |name, index|
            add_file :filename => name, :content => File.open(@@img_path + name, 'rb') { |f| f.read }
            self.attachments[index].content_id = "<#{name}>"
          end
        end

        log_success.puts adresser
        sleep 20
      rescue Exception => e
        log_error.puts   adresser
        log_enotice.puts "#{adresser} => #{e.message}"
      end
    end

    # LOGGING CLOSE
    log_success.close
    log_enotice.close
    log_error.close

    # FALASH
    flash[:notice] = 'Posting is finish'
    redirect '/mail/letter'
  end

  # Routes to COFFEE-JS
  get '/javascripts/:folder/:name.js' do
    content_type 'text/javascript', :charset => 'utf-8'
    coffee :"../../public/javascripts/COFFEE/#{params[:folder]}/#{params[:name]}"
  end

  # Routes to SCSS-CSS
  get '/stylesheets/:folder/:name.css' do
    content_type 'text/css', :charset => 'utf-8'
    scss :"../../public/stylesheets/SCSS/#{params[:folder]}/#{params[:name]}"
  end

end
