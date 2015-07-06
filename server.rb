require 'rubygems'
require 'sinatra'
require 'yaml/store'
require 'securerandom'
require 'json'
require 'thread'
require "net/http"
require "uri"

configure do
  # logging is enabled by default in classic style applications,
  # so `enable :logging` is not needed
  file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
  file.sync = true
  use Rack::CommonLogger, file
end

$job_flag = false
$job_array = Array.new()
$sum = 0

Thread.new do
  while true do
  	if $job_flag == true
      puts 'GOES IN'
      @jobs = YAML::Store.new 'resources/jobs.yml'
      @jobs_data = @jobs.transaction { @jobs['jobs'] } 
      $job_array.each do |item|
        @job = @jobs_data[item]
        # if @job['retry_time'].nil? != true
        #   current_time = Time.now
        #   if current_time < @job['retry_time']
        #     continue
        #   end
        # end
        puts 'GETTING JOB FROM QUEUE..'
        uri = URI.parse(@job['url'])
        response = Net::HTTP.post_form(uri, @job['job'])
        puts response
        if response.body == 'ok'
          puts 'WEBHOOK SENT SUCCESSFULLY'
          @job['status'] = 'COMPLETED'
          puts @job

          @jobs.transaction do
            puts @job
            @jobs['jobs'][item] = @job
          end
        else
          @job['status'] = 'FAILED, PENDING RE-TRY'
          # time = Time.now
          # retry_time = t + 30
          # puts retry_time       
          # @job['retry_time'] = retry_time
          @jobs.transaction do
            puts @job
            @jobs['jobs'][item] = @job
          end
          # $job_flag = true
          # $job_array.push(item)
        end  
      end
  		sleep 0.12
      $job_flag = false
      $job_array = Array.new()
     	$sum += 1
     end
  end
end

get '/start' do
	$job_flag = true
	print($job_flag)
end

# Add job to queue 
post '/add' do
  params = JSON.parse(request.env["rack.input"].read)

  if params['job'].nil? == true || params['hashValue'].nil? == true || params['url'].nil? == true
    # return 500 if no 'job' in json
    error 500, {error: "Missing parameter"}.to_json   
  end

  puts params
  @job = params['job']
  @hashValue = params['hashValue']
  @url = params['url']
  @uuid = params['id']

  if @hashValue != '1FG39012GY236'
    # return 500 if no 'job' in json
    error 500, {error: "Authentication failed"}.to_json  
  end

  # Add the job JSON with URL to jobs.yml
  @new_job = Hash.new
  @new_job = {"id" => @uuid, "url" => @url, "job" => @job, "status" => 'PENDING'}
  @jobs = YAML::Store.new 'resources/jobs.yml'
  @jobs.transaction do
    @jobs['jobs'][@uuid] = @new_job
  end
  
  # Set the global variable flag to true and add job ID to job array
  # The flag will activate the background thread
  $job_flag = true
  puts $job_flag
  $job_array.push(@uuid)

  content_type :json
  { :status => 'Job added to queue', :job_id => @id, :job => @new_job }.to_json

end