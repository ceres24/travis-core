require 'uri'
require 'core_ext/hash/compact'
require 'active_record'

class Repository < ActiveRecord::Base
  has_many :requests, :dependent => :delete_all
  has_many :builds, :dependent => :delete_all do
    def last_status_on(params)
      last_finished_on_branch(params[:branch]).try(:matrix_status, params)
    end
  end

  has_one :last_build,   :class_name => 'Build', :order => 'id DESC', :conditions => { :state  => ['started', 'finished']  }
  has_one :last_success, :class_name => 'Build', :order => 'id DESC', :conditions => { :status => 0 }
  has_one :last_failure, :class_name => 'Build', :order => 'id DESC', :conditions => { :status => 1 }
  has_one :key, :class_name => 'SslKey'

  validates :name,       :presence => true, :uniqueness => { :scope => :owner_name }
  validates :owner_name, :presence => true

  delegate  :public_key, :to => :key

  class << self
    def timeline
      where(arel_table[:last_build_started_at].not_eq(nil)).order(arel_table[:last_build_started_at].desc)
    end

    def recent
      limit(25)
    end

    def by_owner_name(owner_name)
      where(:owner_name => owner_name)
    end

    def by_slug(slug)
      where(:owner_name => slug.split('/').first, :name => slug.split('/').last)
    end

    def search(query)
      query = query.gsub('\\', '\/')
      where('(repositories.owner_name || \'/\' || repositories.name) ~* ?', query)
    end

    def find_by(params)
      if id = params[:id] || params[:repository_id]
        self.find(id)
      else
        self.where(params.slice(:name, :owner_name)).first
      end
    end

    def by_name
      Hash[*all.map { |repository| [repository.name, repository] }.flatten]
    end
  end

  def last_build_status(params = {})
    params = params.symbolize_keys.slice(*Build.matrix_keys_for(params))
    params.blank? ? read_attribute(:last_build_status) : builds.last_status_on(params)
  end

  def slug
    @slug ||= [owner_name, name].join('/')
  end

  def service_hook
    @service_hook ||= ::ServiceHook.new(
      :owner_name => owner_name,
      :name => name,
      :active => active,
      :repository => self
    )
  end

  alias :old_key :key
  def key
    @key ||= old_key || SslKey.create(:repository_id => self.id)
  end

  def branches
    builds.paged({}).includes([:commit]).map{ |build| build.commit.branch }.uniq
  end

end
