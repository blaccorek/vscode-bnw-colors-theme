# frozen_string_literal: true

# Sample Ruby: modules, mixins, blocks, symbols, metaprogramming, exceptions.
require 'json'
require 'logger'
require 'set'

module Bnw
  VERSION = '1.4.2'
  MAX_RETRIES = 3
  SLUG_RE = /[^a-z0-9]+/.freeze

  LOGGER = Logger.new($stdout).tap do |log|
    log.level = Logger::INFO
    log.formatter = ->(severity, time, _prog, msg) { "[#{time.iso8601}] #{severity}: #{msg}\n" }
  end

  module Sluggable
    def slug
      name.to_s.downcase.gsub(SLUG_RE, '-').gsub(/\A-|-\z/, '')
    end
  end

  class RepositoryError < StandardError
    attr_reader :key

    def initialize(key, cause: nil)
      @key = key
      super("failed to persist #{key.inspect}")
      set_backtrace(cause&.backtrace)
    end
  end

  ROLES = %i[admin editor viewer].freeze

  class User
    include Comparable
    include Sluggable

    attr_accessor :name, :email
    attr_reader :id, :roles

    def initialize(id, name, email: nil, roles: [])
      @id = Integer(id)
      @name = name
      @email = email
      @roles = Set.new(roles.map(&:to_sym))
    end

    ROLES.each do |role|
      define_method(:"#{role}?") { roles.include?(role) }
    end

    def <=>(other) = id <=> other.id

    def to_h
      { id: id, name: name, email: email, roles: roles.to_a, slug: slug }
    end

    def to_json(*args) = to_h.to_json(*args)

    def inspect = format('#<User id=%d name=%p roles=%s>', id, name, roles.to_a.join(','))
  end

  class UserRepository
    include Enumerable

    def initialize(namespace: 'users')
      @namespace = namespace
      @items = {}
    end

    def each(&block)
      return enum_for(:each) unless block_given?

      @items.values.sort.each(&block)
    end

    def save(user)
      attempts = 0
      begin
        attempts += 1
        raise ArgumentError, 'blank name' if user.name.to_s.strip.empty?

        @items[user.id] = user
      rescue ArgumentError => e
        retry if attempts < MAX_RETRIES
        raise RepositoryError.new("#{@namespace}:#{user.id}", cause: e)
      ensure
        LOGGER.debug { "save attempt #{attempts} for #{user.id}" }
      end
      user
    end

    def [](id) = @items.fetch(id) { raise RepositoryError, "users:#{id}" }

    def method_missing(name, *args)
      name.to_s.start_with?('find_by_') ? find { |u| u.public_send(name.to_s.delete_prefix('find_by_')) == args.first } : super
    end

    def respond_to_missing?(name, include_private = false)
      name.to_s.start_with?('find_by_') || super
    end
  end
end

repo = Bnw::UserRepository.new
[
  Bnw::User.new(1, 'Ada Lovelace', email: 'ada@example.com', roles: %w[admin]),
  Bnw::User.new(2, 'Grace Hopper', roles: [:editor, :viewer])
].each { |user| repo.save(user) }

admins, others = repo.partition(&:admin?)
summary = repo.map(&:slug).join(', ')

puts <<~REPORT
  bnw-colors #{Bnw::VERSION}
  admins : #{admins.map(&:name).join(', ')}
  others : #{others.size}
  slugs  : #{summary}
  numbers: #{0b1010} #{0o17} #{0xff} #{1_000_000} #{3.14e-2}
REPORT

puts repo.find_by_name('Ada Lovelace')&.to_json
