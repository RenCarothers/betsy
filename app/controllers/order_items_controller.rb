class OrderItemsController < ApplicationController

  def create
    @order_items = current_order
  end

    def cart
      @cart = session[:cart].map { |attributes| OrderItem.new(attributes)}
      # @cart = session[:cart]
      @cart_total = get_total
    end

  def add_to_cart
    initialize_session
    product = Product.find_by(id: params["product_id"])
    quantity = params["selected_quantity"].to_i
    if product.quantity.nil?
      product.quantity = 0
      product.save
    end
    if quantity > product.quantity.to_i
      quantity = product.quantity #if more is added than is available, add remaining
    end

    #verify merchant is not buying own product
    if !can_purchase(product)
      redirect_to products_path
      return
    end

    order_item = OrderItem.new(product_id: product.id, quantity: quantity)

      # find the item in the cart
      # update the quantity
    if session[:cart].empty?
      session[:cart]  << order_item
        flash[:status] = :success
        flash[:result_text] = "Awesome! Your N.E.O.P.E.T.S.Y #{product.name} item is in the cart!"
    else
      #cart is not empty
      if cart_has_item(order_item)
        session[:cart].each do |item|
            if item["product_id"] == order_item.product_id
             item["quantity"] = item["quantity"] + quantity
            end
            flash[:status] = :success
            flash[:result_text] = "Awesome! Your N.E.O.P.E.T.S.Y #{product.name} quantity has been updated!"
        end
      else
        session[:cart]  << order_item
        flash[:status] = :success
        flash[:result_text] = "Great choice! We've added another N.E.O.P.E.T.S.Y. item to your cart!"
      end
    end
    redirect_to cart_path
  end

  def remove
    item_to_remove = params[:product].to_i
    session[:cart].each do |item|
      if item["product_id"] == item_to_remove
        session[:cart].delete(item)
      end
    end

    redirect_to cart_path
  end

  def add_one
    product_id = params[:product].to_i
    product = Product.find_by(id: product_id)
    session[:cart].each do |item|
      if item["product_id"] == product_id
        if item["quantity"] < product.quantity
          item["quantity"] = item["quantity"] + 1
        end
      end
    end
    redirect_to cart_path
  end

  def less_one
    product_id = params[:product].to_i
    session[:cart].each do |item|
      if item["product_id"] == product_id
        if item["quantity"] > 1
          item["quantity"] = item["quantity"] - 1
        end
      end
    end
    redirect_to cart_path
  end

  def cart_has_item(test_item)
    session[:cart].each do |item|
      if item["product_id"] == test_item.product_id
        return true
      end
    end
    return false
  end

  def can_purchase(product)
    if session[:user_id] == product.merchant_id
      flash[:status] = :failure
      flash[:result_text] = "Merchants cannot buy their own products."
      return false
    end
    true
  end

  def get_total
    total = 0.0
    @cart.each do |item|
      total = total + item.product.price * item.quantity
    end
    return total
  end

  def clear_cart
    session[:cart] = []

    redirect_to cart_path
  end

  def update #TODO: Please leave me here, this is for updating status on merchant dash
    unless @login_user
          flash[:status] = :failure
          flash[:result_text] = "Only merchants can update an order item."
          redirect_to root_path
          return
    end

    @order_item = OrderItem.find_by(id: params[:id])

      if order_item_update_params.permitted? #if strong params
        @order_item.update(status: "shipped") # adjust status

        if @order_item.order.order_items.all? { |order_item| order_item.status == "shipped" } #all items in order now shipped, update order status
          @order_item.order.update(status: "complete")
        end

        flash[:status] = :success
        flash[:result_text] = "Successfully updated #{@order_item.product.name} order item(s)."
        redirect_to order_path(@order_item.order.id)
      end
  end

  private

  def initialize_session
    return session[:cart] ||= []
  end

  def order_item_update_params #TODO: This is also for updating status on merchant dash
    return params.require(:order_item).permit(:status)
  end

end
