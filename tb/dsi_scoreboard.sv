class dsi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(dsi_scoreboard)

    uvm_tlm_analysis_fifo #(ppi_xtn) ppi_h;
    uvm_tlm_analysis_fifo #(dc_xtn) dc_h;

    covergroup dc_coverage_cg with function sample(int pixels_per_line);
        option.per_instance = 1;

        line_size: coverpoint pixels_per_line {
            bins configured = {`payload_cnt};
            bins short_line = {[1:`payload_cnt-1]};
            bins long_line  = {[`payload_cnt+1:$]};
            bins empty_line = {0};
        }
    endgroup

    covergroup dc_pixel_coverage_cg with function sample(
        byte unsigned component0,
        byte unsigned component1,
        byte unsigned component2
    );
        option.per_instance = 1;

        component0_value: coverpoint component0{
            bins zero = {8'h00};
            bins low  = {[8'h01:8'h3f]};
            bins mid  = {[8'h40:8'hbf]};
            bins high = {[8'hc0:8'hff]};
        }
        component1_value: coverpoint component1{
            bins zero = {8'h00};
            bins low  = {[8'h01:8'h3f]};
            bins mid  = {[8'h40:8'hbf]};
            bins high = {[8'hc0:8'hff]};
        }
        component2_value: coverpoint component2{
            bins zero = {8'h00};
            bins low  = {[8'h01:8'h3f]};
            bins mid  = {[8'h40:8'hbf]};
            bins high = {[8'hc0:8'hff]};
        }
    endgroup

    covergroup ppi_coverage_cg with function sample(
        logic [3:0] lane_mask,
        byte unsigned lane0_data,
        byte unsigned lane1_data,
        byte unsigned lane2_data,
        byte unsigned lane3_data
    );
        option.per_instance = 1;

        active_lanes: coverpoint lane_mask {
            bins lane0_only = {4'b0001};
            bins lanes0_1   = {4'b0011};
            bins lanes0_2   = {4'b0111};
            bins all_lanes  = {4'b1111};
        }

        lane0_value: coverpoint lane0_data iff (lane_mask[0]) {
            bins zero = {8'h00};
            bins low  = {[8'h01:8'h3f]};
            bins mid  = {[8'h40:8'hbf]};
            bins high = {[8'hc0:8'hff]};
        }
        lane1_value: coverpoint lane1_data iff (lane_mask[1]) {
            bins zero = {8'h00};
            bins low  = {[8'h01:8'h3f]};
            bins mid  = {[8'h40:8'hbf]};
            bins high = {[8'hc0:8'hff]};
        }
        lane2_value: coverpoint lane2_data iff (lane_mask[2]) {
            bins zero = {8'h00};
            bins low  = {[8'h01:8'h3f]};
            bins mid  = {[8'h40:8'hbf]};
            bins high = {[8'hc0:8'hff]};
        }
        lane3_value: coverpoint lane3_data iff (lane_mask[3]) {
            bins zero = {8'h00};
            bins low  = {[8'h01:8'h3f]};
            bins mid  = {[8'h40:8'hbf]};
            bins high = {[8'hc0:8'hff]};
        }
    endgroup

    function new(string name="dsi_scoreboard", uvm_component parent);
        super.new(name,parent);
        ppi_h=new("ppi_h",this);
        dc_h=new("dc_h",this);
        dc_coverage_cg = new();
        dc_pixel_coverage_cg = new();
        ppi_coverage_cg = new();
    endfunction

    byte unsigned expected[$];
    //byte unsigned short_packet[$];
    byte unsigned header[$];
    byte unsigned footer[$];
    byte unsigned observed[$];

    int expected_byte_count;
    int observed_byte_count;
    int mismatch_count;
    int compare_count;
    int match_count;

    function automatic byte unsigned calculate_ecc(
        input logic [(`payload_cnt * 24)-1:0] payload,
        input byte unsigned initial_ecc
    );
        byte unsigned result;

        result = initial_ecc;
        foreach (payload[i])
            result = result ^ payload[i];
        return result;
    endfunction

    function automatic logic [15:0] calculate_crc(
        input logic [(`payload_cnt * 24)-1:0] payload,
        input logic [15:0] initial_crc
    );
        logic [15:0] result;

        result = initial_crc;
        foreach (payload[i]) begin
            if ((result[15] ^ payload[i]) == 1'b1)
                result = {result[14:0], 1'b1} ^ 16'hCAFE;
            else
                result = {result[14:0], 1'b0};
        end
        return result;
    endfunction

    task run_phase(uvm_phase phase);
        fork
            collect_dc_data();
            collect_ppi_data();
        join
    endtask

    task collect_dc_data();
        dc_xtn dxtn;
        forever begin
            dc_h.get(dxtn);
            dc_coverage_cg.sample(dxtn.pixel_data.size());
            foreach (dxtn.pixel_data[i]) begin
                dc_pixel_coverage_cg.sample(dxtn.pixel_data[i][7:0],
                                            dxtn.pixel_data[i][15:8],
                                            dxtn.pixel_data[i][23:16]);
                expected.push_back(dxtn.pixel_data[i][7:0]);
                expected.push_back(dxtn.pixel_data[i][15:8]);
                expected.push_back(dxtn.pixel_data[i][23:16]);
                expected_byte_count += 3;
            end
        end
    endtask

    task collect_ppi_data();
        ppi_xtn pxtn;
        forever begin
            ppi_h.get(pxtn);
            ppi_coverage_cg.sample(
                {pxtn.ppi_lane3_en, pxtn.ppi_lane2_en,
                 pxtn.ppi_lane1_en, pxtn.ppi_lane0_en},
                pxtn.ppi_data_lane0, pxtn.ppi_data_lane1,
                pxtn.ppi_data_lane2, pxtn.ppi_data_lane3
            );
            if (pxtn.ppi_lane0_en)
                observed.push_back(pxtn.ppi_data_lane0);
            if (pxtn.ppi_lane1_en)
                observed.push_back(pxtn.ppi_data_lane1);
            if (pxtn.ppi_lane2_en)
                observed.push_back(pxtn.ppi_data_lane2);
            if (pxtn.ppi_lane3_en)
                observed.push_back(pxtn.ppi_data_lane3);
        end

    endtask

    function void check_phase(uvm_phase phase);
        int i;
        int bytes_per_line;
        int observed_index;
        int expected_line_count;
        int line_index;
        int pixel_index;
        int packet_start;
        int ecc_index;
        int crc_index;
        int ecc_check_count;
        int crc_check_count;
        int ecc_mismatch_count;
        int crc_mismatch_count;
        
        logic [(`payload_cnt * 24)-1:0] reference_payload;
        byte unsigned expected_ecc;
        logic [15:0] expected_crc;

        super.check_phase(phase);
        expected_line_count = 0;
        ecc_check_count = 0;
        crc_check_count = 0;
        ecc_mismatch_count = 0;
        crc_mismatch_count = 0;

        if (expected.size() == 0) begin
            `uvm_error("DSI_SCOREBOARD", "No expected pixel bytes were received")
        end
        else begin
            bytes_per_line = `payload_cnt * 3;
            expected_line_count = expected.size() / bytes_per_line;
            expected_ecc = 0;
            expected_crc = 0;

            for (i = 0; i < expected.size(); i++) begin
                observed_index = 30 + i + (i / bytes_per_line) * 42;
                compare_count++;
                if (observed_index >= observed.size()) begin
                    `uvm_error("DSI_SCOREBOARD",
                               $sformatf("Observed data ended before expected pixel byte %0d (observed index %0d, queue size %0d)",
                                         i, observed_index, observed.size()))
                    break;
                end
              
           
                if (observed[observed_index] !== expected[i]) begin
                    mismatch_count++;
                    `uvm_error("DSI_SCOREBOARD",
                               $sformatf("Pixel byte %0d: expected %02h, got %02h",
                                         i, expected[i], observed[observed_index]))
                end
                else begin
                    match_count++;
                end
            end

            if ((expected.size() % bytes_per_line) != 0) begin
                `uvm_error("DSI_SCOREBOARD",
                           $sformatf("Expected pixel data contains an incomplete line (%0d bytes, line size %0d)",
                                     expected.size() % bytes_per_line, bytes_per_line))
            end

            for (line_index = 0; line_index < expected_line_count; line_index++) begin
                for (pixel_index = 0; pixel_index < `payload_cnt; pixel_index++) begin
                    reference_payload[pixel_index * 24 +: 24] = {
                        expected[line_index * bytes_per_line + pixel_index * 3 + 2],
                        expected[line_index * bytes_per_line + pixel_index * 3 + 1],
                        expected[line_index * bytes_per_line + pixel_index * 3]
                    };
                end

                expected_ecc = calculate_ecc(reference_payload, expected_ecc);
                expected_crc = calculate_crc(reference_payload, expected_crc);

                packet_start = 24 + line_index * (bytes_per_line + 42);
                ecc_index = packet_start + 5;
                crc_index = packet_start + 6 + bytes_per_line;

                if (ecc_index >= observed.size()) 
                begin
                    `uvm_error("DSI_SCOREBOARD",
                               $sformatf("Observed data ended before ECC for line %0d (observed index %0d, queue size %0d)",
                                         line_index, ecc_index, observed.size()))
                end

                else
                begin
                    ecc_check_count++;
                    if (observed[ecc_index] !== expected_ecc) begin
                        ecc_mismatch_count++;
                        `uvm_error("DSI_SCOREBOARD",
                                   $sformatf("ECC for line %0d: expected %02h, got %02h",
                                             line_index, expected_ecc, observed[ecc_index]))
                    end
                end

                if ((crc_index + 1) >= observed.size()) 
                begin
                    `uvm_error("DSI_SCOREBOARD",
                               $sformatf("Observed data ended before CRC for line %0d (observed indices %0d-%0d, queue size %0d)",
                                         line_index, crc_index, crc_index + 1, observed.size()))
                end
                else 
                begin
                    crc_check_count++;
                    if ({observed[crc_index + 1], observed[crc_index]} !== expected_crc) begin
                        crc_mismatch_count++;
                        `uvm_error("DSI_SCOREBOARD",
                                   $sformatf("CRC for line %0d: expected %04h, got %02h%02h",
                                             line_index, expected_crc,
                                             observed[crc_index + 1], observed[crc_index]))
                    end
                end
            end

            if(compare_count < expected.size()) begin
                `uvm_error("DSI_SCOREBOARD",
                           $sformatf("Compared only %0d of %0d expected bytes",
                                     compare_count, expected.size()))
            end
        end

        if (mismatch_count != 0 ||
            ecc_mismatch_count != 0 ||
            crc_mismatch_count != 0) begin
            `uvm_error("DSI_SCOREBOARD",
                       $sformatf("FAIL: compared %0d bytes (%0d pixel mismatches), %0d ECC mismatches, %0d CRC mismatches",
                                 compare_count, mismatch_count,
                                 ecc_mismatch_count, crc_mismatch_count))
        end
        else if (compare_count == expected.size() &&
                 expected_byte_count == expected.size() &&
                 ecc_check_count == expected_line_count &&
                 crc_check_count == expected_line_count) begin
            `uvm_info("DSI_SCOREBOARD",
                      $sformatf("PASS: compared %0d bytes, %0d ECC values, and %0d CRC values",
                                compare_count, ecc_check_count, crc_check_count),
                      UVM_LOW)
        end

        `uvm_info("DSI_COVERAGE",
                  $sformatf("DC line-size: %0.2f%%, DC pixel values: %0.2f%%, PPI lane/data: %0.2f%%",
                            dc_coverage_cg.get_coverage(),
                            dc_pixel_coverage_cg.get_coverage(),
                            ppi_coverage_cg.get_coverage()),
                  UVM_LOW)
    endfunction

endclass
