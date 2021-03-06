class BaseConverter
  def initialize(dry_run:, client:, config:, screen_names: [])
    @dry_run      = dry_run
    @client       = client
    @screen_names = screen_names
    @config       = config

    @files  = Dir.glob File.expand_path(File.join(config['file_dir'], '*'))
    @images = Dir.glob File.expand_path(File.join(config['image_dir'], '*'))
  end
  attr_reader :dry_run, :client, :screen_names, :config, :files, :images

  def convert(content)
    {
      post:     post_params(content),
      comments: content['comments'].map { |c| comments_params(c) }
    }
  end

  private

  def post_params(content)
    raise NotImplementedError.new("You must implement #{self.class}##{__method__}")
  end

  def comment_params(comment_content)
    raise NotImplementedError.new("You must implement #{self.class}##{__method__}")
  end

  def screen_name_for(name)
    return name if screen_names.include?(name)
    'esa_bot'
  end

  def reupload(text)
    return text unless text

    text.gsub(%r{https://docbase.io/file_attachments/[a-z0-9\-\.]+}) do |match|
      basename = File.basename(match)
      local_file = files.find { |file| File.basename(file).end_with?(basename) }
      new_url_for_attachment(match, local_file, dry_run)
    end.gsub(%r{https://image.docbase.io/uploads/[a-z0-9\-\.]+}) do |match|
      basename = File.basename(match)
      local_file = images.find { |file| File.basename(file).end_with?(basename) }
      new_url_for_attachment(match, local_file, dry_run)
    end.gsub('](/images/file_icons/', '](https://docbase.io/images/file_icons/')
  end

  def new_url_for_attachment(match, local_file, dry_run)
    return match if !local_file
    '**will be re-uploaded to esa.io**' if dry_run

    # 再アップロード
    resp = client.upload_attachment(local_file)
    return local_file unless resp.status == 200

    resp.body['attachment']['url']
  end
end
