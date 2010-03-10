require 'rubygems'
require 'sinatra'
require 'json'
require 'httpclient'
require 'open-uri'
require 'pit'

$config = Pit.get("clife.cerevo.com", :require => {
  "username" => "your email in CEREVO LIFE",
  "password" => "your password in CEREVO LIFE"
})

$kaolabo_config = Pit.get("kaolabo", :require => {
  "apikey" => "your api key in kaolabo.com"
})

$clife_domain = "cdev:8002" # "clife.cerevo.com"

helpers do
  def get_clife_photos
    domain = "http://#{$clife_domain}/api/rest1/"
    c = HTTPClient.new
    c.set_auth(domain, $config['username'], $config['password'])
    # レスポンスをblockで扱おうとすると一行づつ処理してしまうので注意
    res = c.get_content("http://#{$clife_domain}/api/rest1/photos")
    begin
      photos = JSON.parse(res)
    rescue
      puts 'parse error'
      puts res
    else
      array = []
      photos.each do |k, v|
        array.push k
      end
      return array
    end
  end

  def get_photo_file(key)
    # 写真を一度ローカルにダウンロードしてそれを表示
    filename = "tmp/img/#{key}.jpg"
    if File.exist?(filename)
      # ダウンロード済みだったらそれを表示
      image = open(filename)
    else
      uri = "http://#{$clife_domain}/api/rest1/photos/#{key}/file/m_full.jpg"
      image = open(uri, :http_basic_authentication => [$config['username'], $config['password']]) do |i|
        open(filename, "w") do |o|
          o.write(i.read)
        end
      end
    end
    return image
  end

  def face_detect(key)
    filename = "tmp/api/#{key}"
    if File.exist?(filename)
      res = open(filename).read
    else
      # clife上の写真を取得するには認証が必要なので、顔ラボにURL形式で渡すことはできない
      # 一度ローカルに取得した写真をPOSTする
      # httpsであることに注意
      api_url = "https://kaolabo.com/api/detect?apikey=#{$kaolabo_config['apikey']}"
      post_data = open("tmp/img/#{key}.jpg")
      c = HTTPClient.new
      res = c.post_content(api_url, post_data, "content-type"=>"image/jpeg")
      open(filename, "w") do |o|
        o.write(res)
      end
    end
    return res
  end
end


# ---------------------------------------------------------------------------


# 全写真の一覧
get '/' do
  # keyの一覧
  photo_ids = get_clife_photos
  array = []
  photo_ids.each do |k|
    array.push "<img width='500px' src='http://localhost:4567/img/#{k}.jpg'><br />"
  end
  array.to_s
end


# 人が写っていると思われる写真の一覧
get '/face' do
  photo_ids = get_clife_photos
  array = []
  photo_ids.each do |k|
    # apiレスポンスのファイルサイズをチェックする
    # 顔認識に成功している場合は、容量が135より大きくなる
    if face_detect(k).size > 135
      array.push "<img width='500px' src='http://localhost:4567/img/#{k}.jpg'><br />"
    end
  end
  array.to_s
end

# photo image
get '/img/:key.jpg' do |key|
  content_type :jpg
  get_photo_file(key)
end





# clife webhook endpoint
post '/' do
    puts params.inspect
    photos = JSON.parse(params['photos'])
    photos.each_pair do |key, value|
      puts key
      puts value.inspect
    end
end



