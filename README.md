JupyterLab macOS Runner
=======================

[lab]: https://jupyterlab.readthedocs.io/en/stable/

Standalone app that runs `jupyter-lab` command in background and opens WebKit window with [*JupyterLab*][lab].

### Configuration

Accessible via `defaults read/write com.nanoant.webapp.JupyterLab`

Following settings (showing default values):
~~~bash
defaults write com.nanoant.webapp.JupyterLab CommandPath "jupyter-lab"
defaults write com.nanoant.webapp.JupyterLab NotebookPath "~/Documents/Notebooks"
defaults write com.nanoant.webapp.JupyterLab Port -int 11011
defaults write com.nanoant.webapp.JupyterLab Token "deadbeefb00b"
~~~

Translate into following invocation:
~~~bash
> $CommandPath --no-browser --ip=127.0.0.1 --port=$Port --notebook-dir=$NotebookPath --NotebookApp.token=$Token
~~~

### Build

Use CMake to build it.

### License

Licensed under [MIT License](LICENSE).

### Disclaimers

Icon borrowed from [JupterLab][lab] project.
