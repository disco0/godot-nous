class_name FileSystemLinkResolver
extends Reference
tool

#const exec_cmd = 'CMD.exe'
#
## %s 1: Full Path
## %s 2: Filename
#const ReadLinkTarget_cmd = """
#dir /ALD /N /OG "%s\\.." | find "<SYMLINKD>" | find "%s ["
#"""
## @TODO: For Windows only, the original game build is for Windows only so its prob fine for now
#static func ReadLinkTarget(link_path: String) -> String:
#	var output = [ ]
#	OS.execute(exec_cmd, ["/C", ReadLinkTarget_cmd % [ link_path, link_path.get_file() ]], true, output)
#	for line in output:
#		print('[ReadLinkTarget] Line: |%s|' % [ line ])
#		if not (line as String).trim_suffix(']'):
#			continue
#		var splits = (line as String).trim_suffix(']').rsplit('[', false, 1)
#		if splits.size() == 0:
#			continue
#		var target = splits[0]
#		print('[ReadLinkTarget]    - %s' % [ target ])
#		return target
#	return ""
#
#func _ready():
#	# var userdir = OS.ProjectSettings.get_user_dir()
#	ReadLinkTarget(ProjectSettings.globalize_path(OS.get_user_data_dir()))
#
