class ScanController < ApplicationController
  before_filter :check_trust, only: [ :paste ]
  before_filter :sanitize_search
  skip_before_filter :verify_authenticity_token  
  def paste
  end
  
  def view
		if params[:current_only] == "true"
			params[:q][:system_name_eq] = request.headers["HTTP_EVE_SOLARSYSTEMNAME"]
		end
    if params[:rid]
      @groups=Group.all
      @s=""
      scan = Scan.where(rid: params[:rid]).first
      dt = Time.parse("11:00 UTC")
      last_dt = Time.parse("11:00 UTC") - 1.day
      if params[:pp]
        per=params[:pp]
      else
        per=10
      end

			if params[:past] == "true"
				dt = dt - 1.day
				last_dt = last_dt - 1.day
			end

      if Time.now.utc > dt 
        @s = Sig.where("( hidden <> 1 or hidden is null ) and scan_id = #{scan.id} and sigs.created_at > '#{dt}'") if scan
      else
        @s = Sig.where("( hidden <> 1 or hidden is null ) and scan_id = #{scan.id} and sigs.created_at > '#{last_dt}'") if scan
      end
      @systems=[ ['Any System',''] ]
      @s.each do |sig|
        @systems.push [ sig.system.name, sig.system.name ] 
      end
      @systems.uniq!
			@search = @s.search(params[:q])
			@sigs = @search.result.page(params[:page]).per(per)
      if @s.empty?
        p="<a href=/scan/view?rid=#{params[:rid]}&past=true>here</a>"
				p=p.html_safe
        flash[:warning] = "No results under that ScanID. Click " + p + " to check if there are results before DT" 
        redirect_to "/scan/paste?rid=#{params[:rid]}"
      end
    else
      flash[:warning] = "Requires ScanID"
      redirect_to root_path
    end
  end

  def add
  end
  
  def parse
    if ! params[:rid]
      scan=Scan.create
      scan.rid = SecureRandom.hex
      scan.save
    else
      scan=Scan.where(rid: params[:rid]).first
      if ! scan
        scan=Scan.new
        scan.rid = params[:rid]
        scan.save
      end
    end
    id = scan.id
    rid = scan.rid
    system_name = request.headers["HTTP_EVE_SOLARSYSTEMNAME"]
    cons_name = request.headers["HTTP_EVE_CONSTELLATIONNAME"]
    
    cons = Cons.where(name: cons_name).first
    if ! cons
      cons = Cons.create(name: cons_name)
    end

    cons_id = cons.id
    
    system = System.where(name: system_name).first
    
    if ! system
      system = System.create(name: system_name, cons_id: cons_id)
    end
    
    system_id = system.id
    
    data=params[:paste]
    data.split("\n").each do |line|
      line.chomp!
      scanrow = line.split("\t")
      if scanrow.length == 6
        type = Type.where(name: scanrow[3]).first
        if type.nil?
          type = Type.create(name: scanrow[3])
        end
        type_id = type.id
        
        group = Group.where(name: scanrow[2]).first
        group_id = group.id
        sig_id = scanrow[0]  
        
        Sig.create(sig_id: scanrow[0], group_id: group_id, type_id: type_id, scan_id: scan.id, system_id: system_id )
      end
    end
    redirect_to "/scan/view?#{ params.except(:action, :controller, :commit).to_query }"
  end
  def delete
    if params[:sig_id]
      sig=Sig.where(sig_id: params[:sig_id]).first
      if sig
        sig.hidden = 1
				sig.save
      end
    end
    redirect_to :back
  end
end

private
def check_trust
  if request.headers["HTTP_EVE_TRUSTED"] != "Yes"
    flash[:warning] = "Accept IGB Trust and reload"
    @trust = false
  else
    @trust = true
  end
end


def sanitize_search
  if params[:q]
    # if params[:q].empty?
    #   params.delete(:q)
    # end
  end
end
  
