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

	func get_peer(_id):
		return peer

	func poll():
		pass
