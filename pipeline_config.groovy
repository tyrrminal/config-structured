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
    doc_base_dir = 'dev/docs/modules'
  }
}
