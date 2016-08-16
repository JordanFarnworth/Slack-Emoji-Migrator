require 'rubygems'
require 'capybara'
require 'capybara/dsl'
require 'pry'
require 'pry-nav'
require "dotenv"
require "byebug"
require "httparty"
require 'open-uri'
require 'ostruct'
require 'capybara/rspec'
require 'colorize'


Dotenv.load(*Dir['./.env*.local'])

Capybara.run_server = false
Capybara.current_driver = :selenium

class Wizard
  include Capybara::DSL

  def initialize
    puts "set path to #{Dir.pwd}".colorize(:yellow)
    @path = Dir.pwd
    @errors = []
  end

  def get_emojis
    puts "getting emojis".colorize(:yellow)
    emojis = HTTParty.get('http://slackmojis.com/emojis.json')
    download_images emojis.body
  rescue => e
    puts "#{e}"
    []
  end

  def download_images emojis
    emojis = parsed_json emojis
    puts "parsed #{emojis.length} emojis".colorize(:yellow)
    emojis = emojis.map {|e| OpenStruct.new(e)}
    puts "downloading now".colorize(:yellow)
    new_emojis = []
    emojis.each do |e|
      download = open(e.image_url)
      if Dir[@path + "/emojis/*"].include? @path + "/emojis/"  + "#{e.name}.png"
        e.original_name = "#{e.name}"
        if Dir[@path + "/new_emojis/*"].include? @path + "/new_emojis/"  + "#{e.name}.png"
          num = 1
          while Dir[@path + "/new_emojis/*"].include? @path + "/new_emojis/"  + "#{e.name}.png"
            e.name = "#{e.original_name}_#{num}"
            num = num + 1
          end
          IO.copy_stream(download, "./new_emojis/#{e.name}.png")
          new_emojis << e
          puts "saved: " + "./new_emojis/#{e.name}.png".colorize(:light_blue)
        else
          new_emojis << e
          puts "saved: " + "./new_emojis/#{e.name}.png".colorize(:light_blue)
          IO.copy_stream(download, "./new_emojis/#{e.name}.png")
        end
      else
        IO.copy_stream(download, "./emojis/#{e.name}.png")
        puts "saved: " + "./emojis/#{e.name}.png".colorize(:light_blue)
      end
    end
    puts "downloaded #{new_emojis.length} emojis".colorize(:green)
    debugger if new_emojis.empty?
    new_emojis
  end

  def parsed_json json
    JSON.parse json
  end

  def upload_emojis
    emojis = get_emojis
    _upload_emojis emojis
  end

  def login
    begin
      if email = find('#email')
        fill_in 'email', with: 'jordanfarn23@gmail.com'
        fill_in 'password', with: 'tampasox8*'
        click_on "signin_btn"
      end
    rescue => e
      puts "#{e}".colorize(:red)
      @errors << e
    end
  end

  def attach_file emoji, count = 2, old_file_name = nil
    unless old_file_name.nil?
      page.attach_file('file', @path + "/new_emojis/#{old_file_name}.png")
    else
      page.attach_file('file', @path + "/new_emojis/#{emoji.name}.png")
    end
    fill_in 'emojiname', with: "#{emoji.name}"
    click_on "Save New Emoji"
    begin
      if error = find('.alert.alert_error')
        file_name = old_file_name.nil? ? emoji.name : old_file_name
        emoji.name = emoji.original_name + "_#{count}"
        attach_file emoji, count + 1, file_name
      end
    rescue => e
      puts "#{e}".colorize(:red)
      @errors << "#{e}"
    end
  end

  def _upload_emojis emojis
    puts "uploading emojis..".colorize(:yellow)
    Capybara.app_host = "https://elucidators.slack.com"
    visit('/customize/emoji')
    login
    emojis.each do |emoji|
      attach_file(emoji)
      puts "uploaded: " + "/new_emojis/#{emoji.name}.png".colorize(:light_blue)
    end
    puts "uploaded #{emojis.length} emojis".colorize(:green)
  end
end

wizard = Wizard.new
puts "initialized Wizard class".colorize(:red)
wizard.upload_emojis
