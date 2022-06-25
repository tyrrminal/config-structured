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
    bb_dest_branch = 'master'
    bb_workspace_name = 'concertpharmaceuticals'
    bb_api_base_url = 'https://api.bitbucket.org/2.0/repositories/'
  }
}
