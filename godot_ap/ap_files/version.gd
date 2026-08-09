class_name Version extends Resource

export var major = 0
export var minor = 0
export var build = 0

static func from(json):
	if json["class"] != "Version":
		return null
	var v = Util._ap_load("ap_files/version.gd").new()
	v.major = json["major"]
	v.minor = json["minor"]
	v.build = json["build"]
	return v
static func val(v1, v2, v3):
	var v = Util._ap_load("ap_files/version.gd").new()
	v.major = v1
	v.minor = v2
	v.build = v3
	return v

func _to_string():
	return "VER(%d.%d.%d)" % [major,minor,build]

func compare(other):
	if major != other.major:
		return major - other.major
	if minor != other.minor:
		return minor - other.minor
	return build - other.build

func _as_ap_dict():
	return {"major":major,"minor":minor,"build":build,"class":"Version"}

func _as_semver_dict():
	return {"major":major,"minor":minor,"patch":build}
