require 'ruby-tls'


describe RubyTls do

    class Client2
        def initialize(client_data, dir)
            @client_data = client_data
            @ssl = RubyTls::SSL::Box.new(false, self, private_key: dir + 'client.key', cert_chain: dir + 'client.crt')
        end

        attr_reader :ssl
        attr_accessor :stop
        attr_accessor :server

        def close_cb
            @client_data << 'close'
            @stop = true
        end

        def dispatch_cb(data)
            @client_data << data
        end

        def transmit_cb(data)
            if not @server.started
                @server.started = true
                @server.ssl.start
            end
            @server.ssl.decrypt(data) unless @stop
        end

        def handshake_cb(protocol)
            @client_data << 'ready'
        end
    end

    describe RubyTls::SSL::Box do
        before :each do
            @dir = File.dirname(File.expand_path(__FILE__)) + '/'
            @cert_from_file = File.read(@dir + 'client.crt')
        end

        it "should verify the peer" do
            @server_data = []
            @client_data = []


            class Server2
                def initialize(client, server_data)
                    @client = client
                    @server_data = server_data
                    @ssl = RubyTls::SSL::Box.new(true, self, verify_peer: true)
                end

                attr_reader :ssl
                attr_accessor :started
                attr_accessor :stop
                attr_accessor :cert_from_server

                def close_cb
                    @server_data << 'close'
                    @stop = true
                end

                def dispatch_cb(data)
                    @server_data << data
                end

                def transmit_cb(data)
                    @client.ssl.decrypt(data) unless @stop
                end

                def handshake_cb(protocol)
                    @server_data << 'ready'
                end

                def verify_cb(cert)
                    @server_data << 'verify'
                    @cert_from_server = cert
                    true
                end
            end


            @client = Client2.new(@client_data, @dir)
            @server = Server2.new(@client, @server_data)
            @client.server = @server

            @client.ssl.start
            @client.ssl.cleanup
            @server.ssl.cleanup
            
            expect(@client_data).to eq(['ready'])
            expect(@server_data).to eq(['ready', 'verify', 'verify', 'verify'])
            expect(@server.cert_from_server).to eq(@cert_from_file)
        end


        it "should deny the connection" do
            @server_data = []
            @client_data = []

            class Server3
                def initialize(client, server_data)
                    @client = client
                    @server_data = server_data
                    @ssl = RubyTls::SSL::Box.new(true, self, verify_peer: true)
                end

                attr_reader :ssl
                attr_accessor :started
                attr_accessor :stop
                attr_accessor :cert_from_server

                def close_cb
                    @server_data << 'close'
                    @stop = true
                end

                def dispatch_cb(data)
                    @server_data << data
                end

                def transmit_cb(data)
                    @client.ssl.decrypt(data) unless @stop
                end

                def handshake_cb(protocol)
                    @server_data << 'ready'
                end

                def verify_cb(cert)
                    @server_data << 'verify'
                    @cert_from_server = cert
                    false
                end
            end

            @client = Client2.new(@client_data, @dir)
            @server = Server3.new(@client, @server_data)
            @client.server = @server

            @client.ssl.start
            @client.ssl.cleanup
            @server.ssl.cleanup
            
            expect(@client_data).to eq(['ready'])
            expect(@server_data).to eq(['ready', 'verify', 'close'])

            expect(@server.cert_from_server).to eq(@cert_from_file)
        end
    end
end

