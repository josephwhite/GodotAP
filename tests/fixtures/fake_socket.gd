## Mock peer in WebSocketClient
class FakePeer:
	var sent = []
	var incoming = []

	func put_packet(bytes):
		sent.append(bytes.get_string_from_utf8())

	func get_packet():
		return incoming.pop_front().to_utf8()


## Mock WebSocketClient
class FakeSocket:
	var peer = FakePeer.new()
	## Recorded `set_buffers` args as [in_kb, in_pkts, out_kb, out_pkts], or null.
	var buffers = null
	## URLs passed to `connect_to_url`
	var connected_urls = []
	## Count of `disconnect_from_host` calls
	var disconnects = 0

	func get_peer(_id):
		return peer

	func poll():
		pass

	func set_buffers(in_kb, in_pkts, out_kb, out_pkts):
		buffers = [in_kb, in_pkts, out_kb, out_pkts]
		# Engine returns Error; OK success
		return OK

	func connect_to_url(url):
		connected_urls.append(url)
		# Engine returns Error; OK success
		return OK

	func disconnect_from_host():
		disconnects += 1
