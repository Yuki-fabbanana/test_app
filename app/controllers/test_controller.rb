class TestController < ApplicationController
  def show
  end

  def new
  end

  def create
  end

  def test
  end

  def convert
    params_file = params[:file] ##fdのkeyである"file"を指定している
    file_name = Digest::MD5.hexdigest(Time.now.to_s)
    wav_file_name = file_name + ".wav"
    mp3_file_name = file_name + ".mp3"
    wav_file_path = Rails.root.to_s + "/tmp/songs/" + wav_file_name
    mp3_file_path = Rails.root.to_s + "/tmp/songs/" + mp3_file_name


    File.open(wav_file_path, 'wb') do |f|
      f.write(params_file.tempfile.read.force_encoding("UTF-8"))
    end

    system("ffmpeg -i \"" + wav_file_path + "\" -vn -ac 2 -ar 44100 -ab 256k -acodec libmp3lame -f mp3 \"" + mp3_file_path + "\"")

    # AWS upload
    region = "ap-northeast-1"
    Aws.config.update({
    credentials: Aws::Credentials.new(Rails.application.credentials.aws[:access_key_id],  Rails.application.credentials.aws[:secret_access_key])
    })

    s3 = Aws::S3::Resource.new(region: region)

    file = "#{Rails.root.to_s}/tmp/songs/#{mp3_file_name}"
    bucket = 'proust-songs-database'

    # Get just the file name
    name = File.basename(file)


    # Create the object to upload
    obj = s3.bucket(bucket).object(name)

    # Upload it
    obj.upload_file(file)

    #Delete WAV MP3 File
    FileUtils.rm(wav_file_path)
    FileUtils.rm(mp3_file_path)

    # Create a S3 client
    client = Aws::S3::Client.new(region: region)

    # オブジェクトの既定 ACL の設定
    object_key = name
    object_path = "http://#{bucket}.s3-ap-northeast-1.amazonaws.com/#{object_key}"


    client.put_object_acl({
    acl: "public-read",
    bucket: bucket,
    key: object_key,
    })


    # audDからjsonを取得
    url = URI("https://audd.p.rapidapi.com/?return=timecode%2Capple_music%2Cspotify%2Cdeezer%2Clyrics&spotify_country=ja&url=#{object_path}")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(url)
    request["x-rapidapi-host"] = Rails.application.credentials.audd[:x_rapidapi_host]
    request["x-rapidapi-key"] = Rails.application.credentials.audd[:x_rapidapi_key]

    response = http.request(request)
    p "-----------------"
    puts response.read_body.force_encoding("UTF-8")
    p "-----------------"

    # 詳細見る必要あり
    @result = JSON.parse(response.read_body)

    render :json => @result
  end

  private

  def ensure_correct_user
    post = Post.find(params[:id])
    if post.user_id != current_user.id
      redirect_to map_path
    end
  end

  def address_params
    params.permit(
        :address,
        :latitude,
        :longitude,
        :artist,
        :songs_title,
        :album,
        :release_date,
        :artwork,
        :youtube_link,
        :body,
        :post_image
      )
  end

  def post_params
    params.require(:post).permit(
      :user_id,
      :address,
      :latitude,
      :longitude,
      :artist,
      :songs_title,
      :album,
      :release_date,
      :artwork,
      :youtube_link,
      :body,
      :post_image
    )
  end

end
