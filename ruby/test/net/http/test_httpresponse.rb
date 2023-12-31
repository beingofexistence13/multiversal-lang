# coding: US-ASCII
# frozen_string_literal: false
require 'net/http'
require 'test/unit'
require 'stringio'

class HTTPResponseTest < Test::Unit::TestCase
  def test_singleline_header
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Content-Length: 5
Connection: close

hello
EOS
    res = Net::HTTPResponse.read_new(io)
    assert_equal('5', res['content-length'])
    assert_equal('close', res['connection'])
  end

  def test_multiline_header
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
X-Foo: XXX
   YYY
X-Bar:
 XXX
\tYYY

hello
EOS
    res = Net::HTTPResponse.read_new(io)
    assert_equal('XXX YYY', res['x-foo'])
    assert_equal('XXX YYY', res['x-bar'])
  end

  def test_read_body
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Length: 5

hello
EOS

    res = Net::HTTPResponse.read_new(io)

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    assert_equal 'hello', body
  end

  def test_read_body_body_encoding_false
    body = "hello\u1234"
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Length: #{body.bytesize}

#{body}
EOS

    res = Net::HTTPResponse.read_new(io)

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    assert_equal "hello\u1234".b, body
    assert_equal Encoding::ASCII_8BIT, body.encoding
  end

  def test_read_body_body_encoding_encoding
    body = "hello\u1234"
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Length: #{body.bytesize}

#{body}
EOS

    res = Net::HTTPResponse.read_new(io)
    res.body_encoding = Encoding.find('utf-8')

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    assert_equal "hello\u1234", body
    assert_equal Encoding::UTF_8, body.encoding
  end

  def test_read_body_body_encoding_string
    body = "hello\u1234"
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Length: #{body.bytesize}

#{body}
EOS

    res = Net::HTTPResponse.read_new(io)
    res.body_encoding = 'utf-8'

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    assert_equal "hello\u1234", body
    assert_equal Encoding::UTF_8, body.encoding
  end

  def test_read_body_body_encoding_true_without_content_type_header
    body = "hello\u1234"
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Length: #{body.bytesize}

#{body}
EOS

    res = Net::HTTPResponse.read_new(io)
    res.body_encoding = true

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    assert_equal "hello\u1234".b, body
    assert_equal Encoding::ASCII_8BIT, body.encoding
  end

  def test_read_body_body_encoding_true_with_utf8_content_type_header
    body = "hello\u1234"
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Length: #{body.bytesize}
Content-Type: text/plain; charset=utf-8

#{body}
EOS

    res = Net::HTTPResponse.read_new(io)
    res.body_encoding = true

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    assert_equal "hello\u1234", body
    assert_equal Encoding::UTF_8, body.encoding
  end

  def test_read_body_body_encoding_true_with_iso_8859_1_content_type_header
    body = "hello\u1234"
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Length: #{body.bytesize}
Content-Type: text/plain; charset=iso-8859-1

#{body}
EOS

    res = Net::HTTPResponse.read_new(io)
    res.body_encoding = true

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    assert_equal "hello\u1234".force_encoding("ISO-8859-1"), body
    assert_equal Encoding::ISO_8859_1, body.encoding
  end

  def test_read_body_body_encoding_true_with_utf8_meta_charset
    res_body = "<html><meta charset=\"utf-8\">hello\u1234</html>"
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Length: #{res_body.bytesize}
Content-Type: text/html

#{res_body}
EOS

    res = Net::HTTPResponse.read_new(io)
    res.body_encoding = true

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    assert_equal res_body, body
    assert_equal Encoding::UTF_8, body.encoding
  end

  def test_read_body_body_encoding_true_with_iso8859_1_meta_charset
    res_body = "<html><meta charset=\"iso-8859-1\">hello\u1234</html>"
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Length: #{res_body.bytesize}
Content-Type: text/html

#{res_body}
EOS

    res = Net::HTTPResponse.read_new(io)
    res.body_encoding = true

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    assert_equal res_body.force_encoding("ISO-8859-1"), body
    assert_equal Encoding::ISO_8859_1, body.encoding
  end

  def test_read_body_body_encoding_true_with_utf8_meta_content_charset
    res_body = "<meta http-equiv='content-type' content='text/html; charset=UTF-8'>hello\u1234</html>"
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Length: #{res_body.bytesize}
Content-Type: text/html

#{res_body}
EOS

    res = Net::HTTPResponse.read_new(io)
    res.body_encoding = true

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    assert_equal res_body, body
    assert_equal Encoding::UTF_8, body.encoding
  end

  def test_read_body_body_encoding_true_with_iso8859_1_meta_content_charset
    res_body = "<meta http-equiv='content-type' content='text/html; charset=ISO-8859-1'>hello\u1234</html>"
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Length: #{res_body.bytesize}
Content-Type: text/html

#{res_body}
EOS

    res = Net::HTTPResponse.read_new(io)
    res.body_encoding = true

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    assert_equal res_body.force_encoding("ISO-8859-1"), body
    assert_equal Encoding::ISO_8859_1, body.encoding
  end

  def test_read_body_block
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Length: 5

hello
EOS

    res = Net::HTTPResponse.read_new(io)

    body = ''

    res.reading_body io, true do
      res.read_body do |chunk|
        body << chunk
      end
    end

    assert_equal 'hello', body
  end

  def test_read_body_block_mod
    # http://ci.rvm.jp/results/trunk-rjit-wait@silicon-docker/3019353
    if defined?(RubyVM::RJIT) && RubyVM::RJIT.enabled?
      omit 'too unstable with --jit-wait, and extending read_timeout did not help it'
    end
    IO.pipe do |r, w|
      buf = 'x' * 1024
      buf.freeze
      n = 1024
      len = n * buf.size
      th = Thread.new do
        w.write("HTTP/1.1 200 OK\r\nContent-Length: #{len}\r\n\r\n")
        n.times { w.write(buf) }
        :ok
      end
      io = Net::BufferedIO.new(r)
      res = Net::HTTPResponse.read_new(io)
      nr = 0
      res.reading_body io, true do
        # should be allowed to modify the chunk given to them:
        res.read_body do |chunk|
          nr += chunk.size
          chunk.clear
        end
      end
      assert_equal len, nr
      assert_equal :ok, th.value
    end
  end

  def test_read_body_content_encoding_deflate
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Encoding: deflate
Content-Length: 13

x\x9C\xCBH\xCD\xC9\xC9\a\x00\x06,\x02\x15
EOS

    res = Net::HTTPResponse.read_new(io)
    res.decode_content = true

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    if Net::HTTP::HAVE_ZLIB
      assert_equal nil, res['content-encoding']
      assert_equal '5', res['content-length']
      assert_equal 'hello', body
    else
      assert_equal 'deflate', res['content-encoding']
      assert_equal '13', res['content-length']
      assert_equal "x\x9C\xCBH\xCD\xC9\xC9\a\x00\x06,\x02\x15", body
    end
  end

  def test_read_body_content_encoding_deflate_uppercase
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Encoding: DEFLATE
Content-Length: 13

x\x9C\xCBH\xCD\xC9\xC9\a\x00\x06,\x02\x15
EOS

    res = Net::HTTPResponse.read_new(io)
    res.decode_content = true

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    if Net::HTTP::HAVE_ZLIB
      assert_equal nil, res['content-encoding']
      assert_equal '5', res['content-length']
      assert_equal 'hello', body
    else
      assert_equal 'DEFLATE', res['content-encoding']
      assert_equal '13', res['content-length']
      assert_equal "x\x9C\xCBH\xCD\xC9\xC9\a\x00\x06,\x02\x15", body
    end
  end

  def test_read_body_content_encoding_deflate_chunked
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Encoding: deflate
Transfer-Encoding: chunked

6
x\x9C\xCBH\xCD\xC9
7
\xC9\a\x00\x06,\x02\x15
0

EOS

    res = Net::HTTPResponse.read_new(io)
    res.decode_content = true

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    if Net::HTTP::HAVE_ZLIB
      assert_equal nil, res['content-encoding']
      assert_equal nil, res['content-length']
      assert_equal 'hello', body
    else
      assert_equal 'deflate', res['content-encoding']
      assert_equal nil, res['content-length']
      assert_equal "x\x9C\xCBH\xCD\xC9\xC9\a\x00\x06,\x02\x15", body
    end
  end

  def test_read_body_content_encoding_deflate_disabled
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Encoding: deflate
Content-Length: 13

x\x9C\xCBH\xCD\xC9\xC9\a\x00\x06,\x02\x15
EOS

    res = Net::HTTPResponse.read_new(io)
    res.decode_content = false # user set accept-encoding in request

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    assert_equal 'deflate', res['content-encoding'], 'Bug #7831'
    assert_equal '13', res['content-length']
    assert_equal "x\x9C\xCBH\xCD\xC9\xC9\a\x00\x06,\x02\x15", body, 'Bug #7381'
  end

  def test_read_body_content_encoding_deflate_no_length
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Encoding: deflate

x\x9C\xCBH\xCD\xC9\xC9\a\x00\x06,\x02\x15
EOS

    res = Net::HTTPResponse.read_new(io)
    res.decode_content = true

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    if Net::HTTP::HAVE_ZLIB
      assert_equal nil, res['content-encoding']
      assert_equal nil, res['content-length']
      assert_equal 'hello', body
    else
      assert_equal 'deflate', res['content-encoding']
      assert_equal nil, res['content-length']
      assert_equal "x\x9C\xCBH\xCD\xC9\xC9\a\x00\x06,\x02\x15\r\n", body
    end
  end

  def test_read_body_content_encoding_deflate_content_range
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Accept-Ranges: bytes
Connection: close
Content-Encoding: gzip
Content-Length: 10
Content-Range: bytes 0-9/55

\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03
EOS

    res = Net::HTTPResponse.read_new(io)

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    assert_equal "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03", body
  end

  def test_read_body_content_encoding_deflate_empty_body
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Encoding: deflate
Content-Length: 0

EOS

    res = Net::HTTPResponse.read_new(io)
    res.decode_content = true

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    if Net::HTTP::HAVE_ZLIB
      assert_equal nil, res['content-encoding']
      assert_equal '0', res['content-length']
      assert_equal '', body
    else
      assert_equal 'deflate', res['content-encoding']
      assert_equal '0', res['content-length']
      assert_equal '', body
    end
  end

  def test_read_body_content_encoding_deflate_empty_body_no_length
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Encoding: deflate

EOS

    res = Net::HTTPResponse.read_new(io)
    res.decode_content = true

    body = nil

    res.reading_body io, true do
      body = res.read_body
    end

    if Net::HTTP::HAVE_ZLIB
      assert_equal nil, res['content-encoding']
      assert_equal nil, res['content-length']
      assert_equal '', body
    else
      assert_equal 'deflate', res['content-encoding']
      assert_equal nil, res['content-length']
      assert_equal '', body
    end
  end

  def test_read_body_string
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Length: 5

hello
EOS

    res = Net::HTTPResponse.read_new(io)

    body = ''

    res.reading_body io, true do
      res.read_body body
    end

    assert_equal 'hello', body
  end

  def test_read_body_receiving_no_body
    io = dummy_io(<<EOS)
HTTP/1.1 204 OK
Connection: close

EOS

    res = Net::HTTPResponse.read_new(io)
    res.body_encoding = 'utf-8'

    body = 'something to override'

    res.reading_body io, true do
      body = res.read_body
    end

    assert_equal nil, body
    assert_equal nil, res.body
  end

  def test_read_body_outside_of_reading_body
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Connection: close
Content-Length: 0

EOS

    res = Net::HTTPResponse.read_new(io)

    assert_raise IOError do
      res.read_body
    end
  end

  def test_uri_equals
    uri = URI 'http://example'

    response = Net::HTTPResponse.new '1.1', 200, 'OK'

    response.uri = nil

    assert_nil response.uri

    response.uri = uri

    assert_equal uri, response.uri
    assert_not_same  uri, response.uri
  end

  def test_ensure_zero_space_does_not_regress
    io = dummy_io(<<EOS)
HTTP/1.1 200OK
Content-Length: 5
Connection: close

hello
EOS

    assert_raise Net::HTTPBadResponse do
      Net::HTTPResponse.read_new(io)
    end
  end

  def test_allow_trailing_space_after_status
    io = dummy_io(<<EOS)
HTTP/1.1 200\s
Content-Length: 5
Connection: close

hello
EOS

    res = Net::HTTPResponse.read_new(io)
    assert_equal('1.1', res.http_version)
    assert_equal('200', res.code)
    assert_equal('', res.message)
  end

  def test_normal_status_line
    io = dummy_io(<<EOS)
HTTP/1.1 200 OK
Content-Length: 5
Connection: close

hello
EOS

    res = Net::HTTPResponse.read_new(io)
    assert_equal('1.1', res.http_version)
    assert_equal('200', res.code)
    assert_equal('OK', res.message)
  end

  def test_allow_empty_reason_code
    io = dummy_io(<<EOS)
HTTP/1.1 200
Content-Length: 5
Connection: close

hello
EOS

    res = Net::HTTPResponse.read_new(io)
    assert_equal('1.1', res.http_version)
    assert_equal('200', res.code)
    assert_equal(nil, res.message)
  end

  def test_raises_exception_with_missing_reason
    io = dummy_io(<<EOS)
HTTP/1.1 404
Content-Length: 5
Connection: close

hello
EOS

    res = Net::HTTPResponse.read_new(io)
    assert_equal(nil, res.message)
    assert_raise Net::HTTPClientException do
      res.error!
    end
  end

  def test_read_code_type
    res = Net::HTTPUnknownResponse.new('1.0', '???', 'test response')
    assert_equal Net::HTTPUnknownResponse, res.code_type

    res = Net::HTTPInformation.new('1.0', '1xx', 'test response')
    assert_equal Net::HTTPInformation, res.code_type

    res = Net::HTTPSuccess.new('1.0', '2xx', 'test response')
    assert_equal Net::HTTPSuccess, res.code_type

    res = Net::HTTPRedirection.new('1.0', '3xx', 'test response')
    assert_equal Net::HTTPRedirection, res.code_type

    res = Net::HTTPClientError.new('1.0', '4xx', 'test response')
    assert_equal Net::HTTPClientError, res.code_type

    res = Net::HTTPServerError.new('1.0', '5xx', 'test response')
    assert_equal Net::HTTPServerError, res.code_type
  end

  def test_inspect_response
    res = Net::HTTPUnknownResponse.new('1.0', '???', 'test response')
    assert_equal '#<Net::HTTPUnknownResponse ??? test response readbody=false>', res.inspect

    res = Net::HTTPUnknownResponse.new('1.0', '???', 'test response')
    socket = Net::BufferedIO.new(StringIO.new('test body'))
    res.reading_body(socket, true) {}
    assert_equal '#<Net::HTTPUnknownResponse ??? test response readbody=true>', res.inspect
  end

private

  def dummy_io(str)
    str = str.gsub(/\n/, "\r\n")

    Net::BufferedIO.new(StringIO.new(str))
  end
end
