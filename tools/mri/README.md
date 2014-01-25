Usage
===
`ruby -r /path/to/mruby-girffi/tools/mri/loader.rb path/to/your/script.rb`

```ruby
require path/to/mruby-girffi/tools/mri/loader.rb

# ...
```

Loading MRBGEMs (ruby source only. no C extensions)
===
The ./tools/mri/loader.rb file takes arguments for loading extra MRBGEMs:
* --GFFI_GLIB
* --GFFI_GOBJECT
* --GFFI_GTK2
* --GFFI_GTK3
* --GFFI_WEBKIT1
* --GFFI_WEBKIT3

This would load the extra glib2.0 functionality as well as functionality for Gtk 3.x
`ruby -r /path/to/mruby-girffi/tools/mri/loader.rb path/to/your/script.rb --GFFI_GLIB --GFFI_GTK3`

This assumes that your directory layout is as follows:
`cd path/to/mruby-girffi`
```
ls ../
../mruby-girffi
../mruby-glib2
../mruby-gtk3
```
