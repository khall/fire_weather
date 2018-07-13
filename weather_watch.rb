require 'net/http'
require 'net/smtp'

SENDER_EMAIL = 'fire.warning@monroefiredept.org'
RECIPIENT_EMAILS = ['bigtoe416@yahoo.com', 'rsmith@monroefiredept.org']
TEMPERATURE_TRIGGER = 90
HUMIDITY_TRIGGER = 25
WIND_TRIGGER = 15
NOAA_FIRE_WEATHER_URL = 'https://www.wrh.noaa.gov/fire2/?zone=ORZ604&zonelist=Go&wfo=PQR&header=off'
# https://www.wrh.noaa.gov/fire2/?zone=ORZ604&zonelist=Go&wfo=pqr&interface=fwzones

# pulls fire weather html from web
class FireWeatherPuller
  def initialize(zip_code)
    # url = 'http://www.srh.noaa.gov/maf/version.php?format=txt&product=FWF&site=NWS&issuedby=PQR&ugc=ORZ604'
    # http://forecast.weather.gov/MapClick.php?rand=1123.522249981761&lat=34.1009953&lon=-117.81941970000003&FcstType=json&callback=jsonCallback&_=1434426418096
  end

  def pull
    uri = URI.parse(NOAA_FIRE_WEATHER_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.get(uri.request_uri).body
  end
end

class FireWeatherParser
  attr_reader :text, :latest_text

  def initialize(text)
    @text = text
  end

  def latest_formatted_data
    text.match(/.+<pre>(.*ORZ604.+)<\/pre>.+/m)
    weather_data = Regexp.last_match(1)
    latest_data = get_latest_data(weather_data)
    parse_data(latest_data)
  end

  def get_latest_data(text)
    text.match(/.+?(\.REST OF TODAY\.\.\.|\.TODAY\.\.\.|\.TONIGHT\.\.\.\n)(.+)<br> *<br>/m)
    @latest_text = Regexp.last_match(1) + Regexp.last_match(2)
    Regexp.last_match(2)
  end

  def parse_data(latest_data)
    { temperature: get_high_temperature(latest_data),
        humidity:    get_low_humidity(latest_data),
        wind:       get_high_winds(latest_data)
    }
  end

  def get_high_temperature(latest_data)
    rez = latest_data.match(/TEMPERATURE\.+(AROUND )?(\d+)(-| TO )?(\d+)?./i)
puts rez
    Regexp.last_match(4) || Regexp.last_match(2)
  end

  def get_low_humidity(latest_data)
    latest_data.match(/HUMIDITY\.+(\d+)-\d+ PERCENT/i)
    Regexp.last_match(1)
  end

  def get_high_winds(latest_data)
    latest_data.match(/20-FOOT WINDS\.+(.+)\* CWR/mi)
    winds = Regexp.last_match(1).gsub("\n", '').gsub(/ +/, ' ')
    winds.scan(/(\d+) MPH/i).flatten.map(&:to_i).sort.last
  end
end

class CoordinateLookup
  def initialize(zip_code)
    geocode_key = 'AIzaSyAMb9AOJtg1TsoIAyQPKVl'
    lookup_url = "https://maps.googleapis.com/maps/api/geocode/json?address=#{zip_code}&sensor=false&key=#{geocode_key}"
  end
end

class Mailer
  def self.send(body)
    msg = <<EMAIL
From: Fire Weather Daemon <#{SENDER_EMAIL}>
To: #{RECIPIENT_EMAILS.join(', ')}
Subject: Fire Weather Warning

#{NOAA_FIRE_WEATHER_URL}

Extreme fire behavior expected!

#{body.gsub(/<br>/, "\n")}
EMAIL
    Net::SMTP.start('127.0.0.1') do |smtp|
      smtp.send_message msg, SENDER_EMAIL, RECIPIENT_EMAILS
    end
  end
end

parser = FireWeatherParser.new(FireWeatherPuller.new(0).pull)
latest_factors = parser.latest_formatted_data
triggers = [latest_factors[:temperature].to_i >= TEMPERATURE_TRIGGER,
            latest_factors[:humidity].to_i <= HUMIDITY_TRIGGER,
            latest_factors[:wind].to_i >= WIND_TRIGGER]
puts "# triggers: #{triggers.count(true)} -- factors: #{latest_factors}"
if triggers.count(true) > 1
  Mailer.send(parser.latest_text)
end
