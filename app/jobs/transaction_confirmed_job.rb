class TransactionConfirmedJob < Struct.new(:conversation_id, :community_id)

  include DelayedAirbrakeNotification

  # This before hook should be included in all Jobs to make sure that the service_name is
  # correct as it's stored in the thread and the same thread handles many different communities
  # if the job doesn't have host parameter, should call the method with nil, to set the default service_name
  def before(job)
    # Set the correct service name to thread for I18n to pick it
    ApplicationHelper.store_community_service_name_to_thread_from_community_id(community_id)
  end

  def perform
    transaction = Transaction.find(conversation_id)
    community = Community.find(community_id)
    MailCarrier.deliver_now(PersonMailer.transaction_confirmed(transaction, community))
    if transaction.payment_gateway == :razorpay
      puts "inside job creation for confirmation bro ... the transaction payment_gateway is : " , transaction.payment_gateway
    end  

    if transaction.payment_gateway == :stripe
      payment = StripeService::Store::StripePayment.get(community_id, transaction.id)
      default_available = APP_CONFIG.stripe_payout_delay.to_f.days.from_now
      available_date = (payment[:available_on] || default_available) + 24.hours
      case StripeService::API::Api.wrapper.charges_mode(community_id)
      when :destination then Delayed::Job.enqueue(StripePayoutJob.new(transaction.id, community_id), :priority => 9, :run_at => available_date)
      when :separate then Delayed::Job.enqueue(StripePayoutJob.new(transaction.id, community_id), :priority => 9)
      end
    elsif transaction.payment_gateway == :razorpay 
      payment = RazorpayService::Store::RazorpayPayment.get(transaction.id)
      Delayed::Job.enqueue(RazorpayPayoutJob.new(transaction.id,community_id), :priority => 9)
      puts " the payment is : ", payment 
      puts " payment id " , payment[:payment_id] 
      puts " the order id  " , payment[:order_id]
      puts " the transaction " ,payment[:transaction_id]
      puts "inside job creation for confirmation bro ... the transaction payment_gateway is : " , transaction.payment_gateway
    end  
    end
  end

