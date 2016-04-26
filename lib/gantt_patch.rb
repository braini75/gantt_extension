# Patch of /lib/redmine/helpers/gantt.rb
# 
# Author: Thomas Koch

module GanttPatch
  def self.included(base) # :nodoc:
    base.class_eval do
      def line_for_project(project, options)
        # Skip projects that don't have a start_date or due date
        if project.is_a?(Project) && project.start_date && project.due_date
          label = project.name
          line(project.start_date, project.due_date, false, nil, true, label, options, project)
        end
      end

      def line_for_version(version, options)
        # Skip versions that don't have a start_date
        if version.is_a?(Version) && version.due_date && version.start_date
          label = "#{h(version)} #{h(version.completed_percent.to_f.round)}%"
          label = h("#{version.project} -") + label unless @project && @project == version.project
          line(version.start_date, version.due_date, false ,version.completed_percent, true, label, options, version)
        end
      end

      def line_for_issue(issue, options)
        # Skip issues that don't have a due_before (due_date or version's due_date)
        if issue.is_a?(Issue) && issue.due_before
          label = "#{issue.status.name} #{issue.done_ratio}%"
          markers = !issue.leaf?
          custom_date = false
          if Setting['plugin_gantt_extension'][:gantt_ext_enable] && !Setting['plugin_gantt_extension'][:gantt_ext_wunsch].nil?
            markers = true          
            #custom_date_fields = issue.visible_custom_field_values.select { |x| x.custom_field.field_format == "date" }
            custom_dates = issue.visible_custom_field_values.select { |x| x.custom_field.id == Setting['plugin_gantt_extension'][:gantt_ext_wunsch].to_i }.first     
            custom_date = custom_dates.value.to_date unless custom_dates.nil?          
          end 
          line(issue.start_date, issue.due_before, custom_date , issue.done_ratio, markers, label, options, issue)
        end
      end

      def line(start_date, end_date, custom_dates, done_ratio, markers, label, options, object=nil)
        options[:zoom] ||= 1
        options[:g_width] ||= (self.date_to - self.date_from + 1) * options[:zoom]
        coords = coordinates(start_date, end_date, custom_dates, done_ratio, options[:zoom])
        send "#{options[:format]}_task", options, coords, markers, label, object
      end

      private

      def coordinates(start_date, end_date, custom_date, progress, zoom=nil)
        zoom ||= @zoom
        coords = {}
        # Display custom dates
        if custom_date && custom_date < self.date_to
          coords[:wunsch] = custom_date - self.date_from
        end
        if start_date && end_date && start_date < self.date_to && end_date > self.date_from
          if start_date > self.date_from
            coords[:start] = start_date - self.date_from
            coords[:bar_start] = start_date - self.date_from
          else
            coords[:bar_start] = 0
          end          
          if end_date < self.date_to
            coords[:end] = end_date - self.date_from
            coords[:bar_end] = end_date - self.date_from + 1
          else
            coords[:bar_end] = self.date_to - self.date_from + 1
          end
          if progress
            progress_date = calc_progress_date(start_date, end_date, progress)
            if progress_date > self.date_from && progress_date > start_date
              if progress_date < self.date_to
                coords[:bar_progress_end] = progress_date - self.date_from
              else
                coords[:bar_progress_end] = self.date_to - self.date_from + 1
              end
            end
            if progress_date < Date.today
              late_date = [Date.today, end_date].min
              if late_date > self.date_from && late_date > start_date
                if late_date < self.date_to
                  coords[:bar_late_end] = late_date - self.date_from + 1
                else
                  coords[:bar_late_end] = self.date_to - self.date_from + 1
                end
              end
            end
          end
        end
        # Transforms dates into pixels witdh
        coords.keys.each do |key|
          coords[key] = (coords[key] * zoom).floor
        end
        coords
      end

      def html_task(params, coords, markers, label, object)
        output = ''

        css = "task " + case object
          when Project
            "project"
          when Version
            "version"
          when Issue
            object.leaf? ? 'leaf' : 'parent'
          else
            ""
          end

        # Renders the task bar, with progress and late
        if coords[:bar_start] && coords[:bar_end]
          width = coords[:bar_end] - coords[:bar_start] - 2
          style = ""
          style << "top:#{params[:top]}px;"
          style << "left:#{coords[:bar_start]}px;"
          style << "width:#{width}px;"
          html_id = "task-todo-issue-#{object.id}" if object.is_a?(Issue)
          html_id = "task-todo-version-#{object.id}" if object.is_a?(Version)
          content_opt = {:style => style,
                         :class => "#{css} task_todo",
                         :id => html_id}
          if object.is_a?(Issue)
            rels = issue_relations(object)
            if rels.present?
              content_opt[:data] = {"rels" => rels.to_json}
            end
          end
          output << view.content_tag(:div, '&nbsp;'.html_safe, content_opt)
          if coords[:bar_late_end]
            width = coords[:bar_late_end] - coords[:bar_start] - 2
            style = ""
            style << "top:#{params[:top]}px;"
            style << "left:#{coords[:bar_start]}px;"
            style << "width:#{width}px;"
            output << view.content_tag(:div, '&nbsp;'.html_safe,
                                       :style => style,
                                       :class => "#{css} task_late")
          end
          if coords[:bar_progress_end]
            width = coords[:bar_progress_end] - coords[:bar_start] - 2
            style = ""
            style << "top:#{params[:top]}px;"
            style << "left:#{coords[:bar_start]}px;"
            style << "width:#{width}px;"
            html_id = "task-done-issue-#{object.id}" if object.is_a?(Issue)
            html_id = "task-done-version-#{object.id}" if object.is_a?(Version)
            output << view.content_tag(:div, '&nbsp;'.html_safe,
                                       :style => style,
                                       :class => "#{css} task_done",
                                       :id => html_id)
          end
        end
        # Renders the markers
        if markers
          if coords[:start]
            style = ""
            style << "top:#{params[:top]}px;"
            style << "left:#{coords[:start]}px;"
            style << "width:15px;"
            output << view.content_tag(:div, '&nbsp;'.html_safe,
                                       :style => style,
                                       :class => "#{css} marker starting")
          end
          if coords[:end]
            style = ""
            style << "top:#{params[:top]}px;"
            style << "left:#{coords[:end] + params[:zoom]}px;"
            style << "width:15px;"
            output << view.content_tag(:div, '&nbsp;'.html_safe,
                                       :style => style,
                                       :class => "#{css} marker ending")
          end
          
          # Render custom date
          if coords[:wunsch]
            style = ""
            style << "top:#{params[:top]}px;"
            style << "left:#{coords[:wunsch] + params[:zoom]}px;"
            style << "width:15px;"
            output << view.content_tag(:div, '&nbsp;'.html_safe,
                                       :style => style,
                                       :class => "#{css} marker wunsch")
          end
        end
        # Renders the label on the right
        if label
          style = ""
          style << "top:#{params[:top]}px;"
          style << "left:#{(coords[:bar_end] || 0) + 8}px;"
          style << "width:15px;"
          output << view.content_tag(:div, label,
                                     :style => style,
                                     :class => "#{css} label")
        end
        # Renders the tooltip
        if object.is_a?(Issue) && coords[:bar_start] && coords[:bar_end]
          s = view.content_tag(:span,
                               view.render_issue_tooltip(object).html_safe,
                               :class => "tip")
          style = ""
          style << "position: absolute;"
          style << "top:#{params[:top]}px;"
          style << "left:#{coords[:bar_start]}px;"
          style << "width:#{coords[:bar_end] - coords[:bar_start]}px;"
          style << "height:12px;"
          output << view.content_tag(:div, s.html_safe,
                                     :style => style,
                                     :class => "tooltip")
        end
        @lines << output
        output
      end
      
    end
  end
end

unless Redmine::Helpers::Gantt.include? GanttPatch
  Redmine::Helpers::Gantt.send(:include, GanttPatch)
end