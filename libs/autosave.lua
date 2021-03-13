--[[
		Lua library to handle autosave module setup.

		addSearchPath - adds a given path to the requestfile path

		setSavePath - Sets the savefile path

		autobuild - Enables/disables autosaveBuild, takes in a table
			of settings described below.

			Required:

				filepath - where the autobuilt file should reside

				filename - the name the autobuilt file should have

				suffix   - the file suffix autobuild will search for
				           to find req files to include


			Optional:

				enable  - Default: 1,    Enable or Disable the autobuild
				                         for the given file

				pass0   - Default: true, restore file on pass0

				pass1   - Default: true, restore file on pass1


				prefix  - Default: "",   IOC Prefix

				monitor - Default: 5,    monitor rate for updates



		All save_restoreSet_XXXX functions have also been implemented as
		autosave.XXXX. On loading of the library, certain defaults will be
		set.

			CAReconnect = 1
			IncompleteSetsOk = 1
			DatedBackupFiles = 1
			NumSeqFiles = 3
			SeqPeriodInSeconds = 300
			CallbackTimeout = -1
			Debug = 0
   ]]

local autosave = { }

function autosave.addSearchPath(path)
	set_requestfile_path(path)
end

function autosave.setSavePath(path)
	set_savefile_path(path)
end

function autosave.autobuild(settings)
	local filepath = assert(settings.filepath)
	local filename = assert(settings.filename)
	local suffix = assert(settings.suffix)

	local enable = (settings.enable or 1)
	local pass0 = (settings.pass0 or true)
	local pass1 = (settings.pass1 or true)

	local prefix = (settings.prefix or "")
	local monitor = (settings.monitor or 5)

	if (enable) then
		if (pass0) then
			set_pass0_restoreFile(filename)
		end

		if (pass1) then
			set_pass1_restoreFile(filename)
		end

		doAfterIocInit(string.format("create_monitor_set('%s', %d, P=%s)", filename, monitor, prefix))
	end

	autosaveBuild(filepath .. "/" .. filename, suffix, enable)
end


autosave.CAReconnect = save_restoreSet_CAReconnect
autosave.IncompleteSetsOk = save_restoreSet_IncompleteSetsOk
autosave.DatedBackupFiles = save_restoreSet_DatedBackupFiles
autosave.NumSeqFiles = save_restoreSet_NumSeqFiles
autosave.SeqPeriodInSeconds = save_restoreSet_SeqPeriodInSeconds
autosave.CallbackTimeout = save_restoreSet_CallbackTimeout
autosave.Debug = save_restoreSet_Debug

autosave.CAReconnect(1)
autosave.IncompleteSetsOk(1)
autosave.DatedBackupFiles(1)
autosave.NumSeqFiles(3)
autosave.SeqPeriodInSeconds(300)
autosave.CallbackTimeout(-1)
autosave.Debug(0)

return autosave
