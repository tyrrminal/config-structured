/* groovylint-disable CompileStatic */
jte {
  reverse_library_resolution = true
}

libraries {
  audit {
    cpanfile_path = './'
  }
  apprise
  perl
  mkdocs {
    bb_repo_slug = 'config-structured'
  }
}
