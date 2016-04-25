Redmine::Plugin.register :gantt_extension do
  name 'Gantt Extension plugin'
  author 'Thomas Koch'
  description 'Show a user defined date (custom field) in gantt'
  version '0.1'
  url 'https://github.com/braini75/gantt_extension'
  author_url 'https://github.com/braini75'
  require_dependency 'gantt'
  
  settings :default => {
    :gantt_ext_enable => 0
    }, :partial => 'settings/gantt_extension'
end

class GanttExtensionViewListener < Redmine::Hook::ViewListener
   def view_layouts_base_html_head(context)
     stylesheet_link_tag('styles', :plugin => :gantt_extension )
   end
end