require 'oauth2'
require 'net/http'
require 'uri'
require 'json'
require 'nokogiri'
require 'date'
require 'fileutils'

# OAuth2の認証情報を設定
CLIENT_ID = '*** ご自身のClient IDを設定してください ***'
CLIENT_SECRET = '*** ご自身のClient secretを設定してください ***'
REDIRECT_URI = 'localhost'
REQUEST_SCOPE = 'innerscan'

AUTHORIZATION_SERVER_BASE_URL = 'https://www.healthplanet.jp'
INNERSCAN_URL = "#{AUTHORIZATION_SERVER_BASE_URL}/status/innerscan.xml"

DATE_FROM = 20250301000000
DATE_TO = 20250530000000
RESULT_OUTPUT_DIR = 'result'

def fetch_token
  client = OAuth2::Client.new(CLIENT_ID, CLIENT_SECRET,
                               site: AUTHORIZATION_SERVER_BASE_URL,
                               auth_scheme: :request_body)

  authorization_url = client.auth_code.authorize_url(redirect_uri: REDIRECT_URI, scope: REQUEST_SCOPE)
  puts "\n\n下記のURLをブラウザーにコピーして、認可コードを取得してください\n"
  puts authorization_url
  puts "\n\n"
  code = gets.chomp
  puts "ブラウザーに表示された認可コードをコピーしてください: #{code}"

  token = client.auth_code.get_token(code, redirect_uri: REDIRECT_URI)
  token.to_hash.to_json
end

def fetch_resource_server(token)
  uri = URI.parse("#{INNERSCAN_URL}?access_token=#{JSON.parse(token)['access_token']}&tag=6021,6022&date=0&from=#{DATE_FROM}&to=#{DATE_TO}")
  response = Net::HTTP.get_response(uri)
  response.body
end

def parse_xml(xml_str)
  doc = Nokogiri::XML(xml_str)
  data_dict = {}
  doc.xpath('//data').each do |data_elem|
    date_elem = data_elem.at_xpath('date')
    date = date_elem.text

    data_dict[date] ||= {}

    tag = data_elem.at_xpath('tag').text
    keydata = data_elem.at_xpath('keydata').text
    model = data_elem.at_xpath('model').text
    data_dict[date]['model'] = model

    case tag
    when '6021'
      key = '体重'
    when '6022'
      key = '体脂肪率'
    else
      key = '不明'
    end

    data_dict[date][key] = keydata
  end

  str_array = []
  data_dict.each do |key_date, result_dict|
    date_result = "#{key_date},"
    date_result += "#{result_dict['model']}," if result_dict.key?('model')
    date_result += "#{result_dict['体重']}," if result_dict.key?('体重')
    date_result += "#{result_dict['体脂肪率']}" if result_dict.key?('体脂肪率')
    str_array << date_result
  end
  str_array
end

def array_to_file(str_array)
  FileUtils.mkdir_p(RESULT_OUTPUT_DIR) unless Dir.exist?(RESULT_OUTPUT_DIR)

  now = DateTime.now
  out_file = now.strftime('%Y%m%d%H%M%S') + '.csv'
  out_path = File.join(RESULT_OUTPUT_DIR, out_file)
  absolute_path = File.expand_path(out_path)
  puts "\n\n"
  puts "#{absolute_path} に結果を出力します"

  File.open(out_path, 'w') do |file|
    str_array.each { |item| file.puts(item) }
  end
end


# トークン類の取得
token_str = fetch_token

# リソースサーバよりデータを取得
response_body = fetch_resource_server(token_str)

# ヘルスプラネットが返却する生のXMLデータを確認するならここでputs
# puts "start ###########################"
puts response_body
# puts "end #############################"

ret_array = parse_xml(response_body)

# 出力内容を puts するならここで
# puts ret_array

array_to_file(ret_array)
