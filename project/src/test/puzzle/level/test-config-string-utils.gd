extends "res://addons/gut/test.gd"

func test_ints_from_config_string() -> void:
	assert_eq([], ConfigStringUtils.ints_from_config_string(""))
	assert_eq([2], ConfigStringUtils.ints_from_config_string("2"))
	assert_eq([1, 3, 5], ConfigStringUtils.ints_from_config_string("1,3,5"))
	assert_eq([0, 1, 2, 3], ConfigStringUtils.ints_from_config_string("0-3"))
	assert_eq([1, 2, 4, 5], ConfigStringUtils.ints_from_config_string("1-2,4-5"))
	assert_eq([0, 4, 5, 6], ConfigStringUtils.ints_from_config_string("0,4-6"))
	assert_eq([2, 3, 4, 6, 13], ConfigStringUtils.ints_from_config_string("6,2-4,13"))


func test_config_string_from_ints() -> void:
	assert_eq("", ConfigStringUtils.config_string_from_ints([]))
	assert_eq("2", ConfigStringUtils.config_string_from_ints([2]))
	assert_eq("1,3,5", ConfigStringUtils.config_string_from_ints([1, 3, 5]))
	assert_eq("1-2,4-5", ConfigStringUtils.config_string_from_ints([1, 2, 4, 5]))
	assert_eq("0-3", ConfigStringUtils.config_string_from_ints([0, 1, 2, 3]))
	assert_eq("0,4-6", ConfigStringUtils.config_string_from_ints([0, 4, 5, 6]))
	assert_eq("2-4,6,13", ConfigStringUtils.config_string_from_ints([4, 3, 6, 13, 2]))