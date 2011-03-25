class ApisController < ApplicationController #We should start with this versioned, V0ApisController  BEES
  before_filter :authenticate_user!, :only => [:home_timeline, :user_timeline]
  respond_to :json
  
  #posts
  def public_timeline
    set_defaults
    timeline = StatusMessage.where(:public => true).includes(:photos, :author => :profile).paginate(:page => params[:page], :per_page => params[:per_page], :order => "#{params[:order]} DESC")
    respond_with timeline do |format|
      format.json{ render :json => timeline.to_json(:format => :twitter) }
    end
  end

  def user_timeline #No public timeline for a user? - R
    set_defaults

    person_id = params[:user_id] || current_user.person.guid # I wouldn't put implicit params in anything meant to be programatically accessed - R

    if person = Person.where(:guid => person_id).first
      timeline = current_user.posts_from(person)
      respond_with timeline do |format|
        format.json{ render :json => timeline.to_json(:format => :twitter) }
      end
    else
      render :json => {:status => 'failed', :reason => 'user not found'}, :status => 404
    end
  end

  def home_timeline
    set_defaults

    aspect_ids = current_user.aspects.map{|a| a.id}
    timeline = StatusMessage.joins(:aspects).where(:pending => false,
             :aspects => {:id => aspect_ids}).includes(:comments, :photos, :likes, :dislikes).select('DISTINCT `posts`.*').paginate(
             :page => params[:page], :per_page => params[:per_page], :order => "#{params[:order]} DESC")

    respond_with timeline do |format|
      format.json{ render :json => timeline.to_json(:format => :twitter) }
    end
  end

  def statuses
    status = StatusMessage.where(:guid => params[:guid], :public => true).includes(:photos, :author => :profile).first
    if status
      respond_with status do |format|
        format.json{ render :json => status.to_json(:format => :twitter) }
      end
    else
      render(:nothing => true, :status => 404) 
    end
  end

  #people
  def users
    if params[:user_id]
      person = Person.where(:guid => params[:user_id]).first
    elsif params[:screen_name]
      person = Person.where(:diaspora_handle => params[:screen_name]).first
    end

    if person
      respond_with person do |format|
        format.json{ render :json => person.to_json(:format => :twitter) }
      end
    else
      render(:nothing => true, :status => 404) 
    end
  end

  def users_search
    set_defaults

    if params[:q]
      people = Person.public_search(params[:q]).paginate(:page => params[:page], :per_page => params[:per_page], :order => "#{params[:order]} DESC")
    end

    if people
      respond_with people do |format|
        format.json{ render :json => people.to_json(:format => :twitter) }
      end
    else
      render(:nothing => true, :status => 404) 
    end
  end

  def users_profile_image
    if person = Person.where(:diaspora_handle => params[:screen_name]).first
      redirect_to person.profile.image_url
    else
      render(:nothing => true, :status => 404)
    end
  end

  #tags
  def tag_posts
    set_defaults
    posts = StatusMessage.where(:public => true, :pending => false)
    posts = posts.tagged_with(params[:tag])
    posts = posts.includes(:comments, :photos).paginate(:page => params[:page], :per_page => params[:per_page], :order => "#{params[:order]} DESC")
    render :json => posts.as_json(:format => :twitter)
  end

  def tag_people
    set_defaults
    profiles = Profile.tagged_with(params[:tag]).where(:searchable => true).select('profiles.id, profiles.person_id')
    people = Person.where(:id => profiles.map{|p| p.person_id}).paginate(:page => params[:page], :per_page => params[:per_page], :order => "#{params[:order]} DESC")
    render :json => people.as_json(:format => :twitter)
  end

  protected
  def set_defaults
    params[:per_page] ||= 20
    params[:order] = 'created_at' unless ['created_at', 'updated_at'].include?(params[:order])
    params[:page] ||= 1
  end
end
