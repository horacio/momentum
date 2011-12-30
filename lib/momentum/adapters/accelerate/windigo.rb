module Momentum::Adapters
  class Accelerate
    class Windigo < Unicorn::HttpServer
      HEADERS = 0x01
      BODY_CHUNK = 0x02
      SPDY_PUSH = 0x03
      
      def send_frame(client, type, text)
        client.write(type)
        data = text.force_encoding('ASCII-8BIT')
        client.write [data.length].pack('L')
        client.write(data)
        
        puts "wrote frame len=#{data.length}"
      end

      def process_client(client)
        puts "connection opened"
        d = client.read(4)
        raise "client closed connection" unless d
        len = d.unpack('L').first
        puts "read len=#{len}"
        
        data = client.read(len)
        puts "read data"
        request = Marshal.load(data)
        puts "got req #{request.inspect}"
        
        env = request.to_rack_env
        env['spdy'] = Momentum::AppDelegate.new @req do |type, payload|
          if type == :push
            send_frame(client, SPDY_PUSH, payload)
          else
            raise "Unknown SPDY callback #{type}"
          end
        end

        status, headers, body = @app.call(env)
        headers['status'] = status
        
        send_frame(client, HEADERS, Marshal.dump(headers))
        
        body.each do |chunk|
          send_frame(client, BODY_CHUNK, chunk)
          
        end
        
        client.close
      rescue Exception => e
        puts e.inspect
        e.backtrace.each { |l| puts l }
        client.close
      end

    end
  end
end