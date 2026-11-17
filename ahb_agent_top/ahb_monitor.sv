class ahb_monitor extends uvm_monitor ;
    `uvm_component_utils(ahb_monitor)

    ahb_agent_config ahb_cfg;
    virtual ahb_if.ahb_mon_mp vif;
    uvm_analysis_port #(ahb_xtn) ahb_port;

    bit pending_valid;
    ahb_xtn mon_xtn;
    //ahb_xtn pending_tr;

    function new(string name="ahb_mon",uvm_component parent);
        super.new(name,parent);
        ahb_port = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(ahb_agent_config)::get(this, "", "ahb_agent_config", ahb_cfg))
            `uvm_fatal(get_full_name(), "failed to get ahb agent config")
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        vif = ahb_cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);
        forever 
            begin
                @(vif.ahb_mon_cb);
                if(vif.ahb_mon_cb.hready==1'b1 && vif.ahb_mon_cb.hwrite==1'b1)
                begin
                mon_xtn=ahb_xtn::type_id::create("mon_xtn");
                mon_xtn.haddr=vif.ahb_mon_cb.haddr;
                mon_xtn.hwrite=vif.ahb_mon_cb.hwrite;
                mon_xtn.hsize=vif.ahb_mon_cb.hsize;
                mon_xtn.hburst=vif.ahb_mon_cb.hburst;
                mon_xtn.htrans=vif.ahb_mon_cb.htrans;
                mon_xtn.hprot=vif.ahb_mon_cb.hprot;
                @(vif.ahb_mon_cb);
                mon_xtn.hwdata=vif.ahb_mon_cb.hwdata;

                ahb_port.write(mon_xtn);
                // `uvm_info(get_type_name(),
                  //            $sformatf("Observed AHB transaction:\n%s", mon_xtn.sprint()),
                    //          UVM_MEDIUM)
                end    
            end
    endtask
endclass
