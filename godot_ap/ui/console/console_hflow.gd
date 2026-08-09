class_name ConsoleHFlow extends Container

func _init():
	add_constant_override("h_separation", 0)
	add_constant_override("v_separation", 0)

func _notification(what):
	match what:
		NOTIFICATION_SORT_CHILDREN:
			_sort_flow()

func _sort_flow():
	var line_h = 0.0
	var x = 0.0
	var y = 0.0
	var max_x = rect_size.x
	for child in get_children():
		var c = child as Control
		if not c:
			continue
		if c.has_method("handle_sizing"):
			c.handle_sizing(self)
		var ms = c.get_combined_minimum_size()
		if x + ms.x > max_x and x > 0:
			y += line_h
			x = 0
			line_h = 0
		fit_child_in_rect(c, Rect2(Vector2(x, y), ms))
		x += ms.x
		line_h = max(line_h, ms.y)
	var total_h = y + line_h
	if not is_equal_approx(rect_min_size.y, total_h):
		rect_min_size.y = total_h

func add_text_split(main_label):
	if main_label.text.find(" ") == -1:
		add_child(main_label)
		return
	var words = main_label.text.split(" ")
	main_label.text = ""
	var labels = []
	var hspace = round(main_label.get_font("font").get_string_size(" ").x)
	for word in words:
		var d = main_label.make_dupe()
		d.text = word
		labels.append(d)
		var spacing = Spacing.new(self, hspace)
		labels.append(spacing)
	if labels.size() == 0: return
	labels.pop_back()
	for lbl in labels:
		add_child(lbl)
