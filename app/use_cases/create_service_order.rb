class CreateServiceOrder
  include UseCase
  include Pundit

  class UnapprovedProject < UseCase::Error
  end

  class UnnamedService < UseCase::Error
  end

  class MissingProject < UseCase::Error
  end

  class MissingProduct < UseCase::Error
  end

  class PersistError < UseCase::Error
  end

  class BudgetError < UseCase::Error
  end

  attr_reader :order

  def initialize(current_user, order_params)
    @user = current_user
    @params = order_params
    @total_cost = 0
  end

  def perform
    validate
    build_order
    authorize order, :create?
    save
    provision_service
  end

  private

  attr_reader :user, :params

  def validate
    unless project.approved?
      fail UnapprovedProject, "Project '#{project.name}' has not been approved."
    end

    validate_name

    unless total_cost + project.monthly_spend <= project.monthly_budget
      fail BudgetError, 'Adding this service will exceed the Project\'s monthly budget.'
    end
  end

  def validate_name
    params[:products].each do |product|
      unless product[:service]['name'].present?
        fail UnnamedService, 'A name for the service was not given.'
      end
    end
  end

  def total_cost
    products.each do |product|
      @total_cost += product[:monthly_price]
    end
    @total_cost
  end

  def build_service(service, product_id)
    service.type = service.class.to_s
    service.status = :pending
    service.status_msg = 'Provisioning service...'
    service.product_id = product_id
    service
  end

  def build_order
    @setup_price = 0
    @hourly_price = 0
    @monthly_price = 0

    products.each do |product|
      @setup_price += product.setup_price
      @hourly_price += product.hourly_price
      @monthly_price += product.monthly_price
    end

    order_params = {
      staff: user,
      project_id: params[:project_id],
      setup_price: @setup_price,
      hourly_price: @hourly_price,
      monthly_price: @monthly_price,
      services: services
    }

    @order = Order.new order_params
  end

  def save
    # Saving the service will also save the order
    services.map do |service|
      unless service.save
        fail PersistError, 'The service could not be created.'
      end
    end
    unless order.save
      fail PersistError, 'The order could not be created.'
    end
  end

  def provision_service
    services.map do |service|
      service.delay.provision
    end
  end

  def project
    @project ||= Project.find params[:project_id]
  rescue ActiveRecord::RecordNotFound
    raise MissingProject, 'The associated project cannot be located.'
  end

  def products
    product_ids = []
    params[:products].each do |product|
      product_ids.push(product[:product_id])
    end
    @products ||= Product.find(product_ids)
  rescue ActiveRecord::RecordNotFound
    raise MissingProduct, 'The associated product cannot be located.'
  end

  def service_class(product_id)
    @service_class ||= {}
    @service_class[product_id] ||= Product.find(product_id).service_class
  end

  def services
    @services ||= params[:products].map do |product|
      klass = service_class product[:product_id]
      @service = klass.new(product.delete :service)
      @service = build_service(@service, product[:product_id])
    end
  end

  def current_user
    @user
  end
end
