Redmine::Plugin.register :gantt_extension do
  name 'Gantt Extension plugin'
  author 'Thomas Koch'
  description 'Show a user defined date (custom field) in gantt'
  version '0.2'
  url 'https://github.com/braini75/gantt_extension'
  author_url 'https://github.com/braini75'
    
  settings :default => {
    :gantt_ext_enable => 0
    }, :partial => 'settings/gantt_extension'
end

require_dependency 'gantt_patch'

class GanttExtensionViewListener < Redmine::Hook::ViewListener
   def view_layouts_base_html_head(context)
     stylesheet_link_tag('styles', :plugin => :gantt_extension )
   end
end