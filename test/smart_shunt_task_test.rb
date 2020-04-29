# frozen_string_literal: true

using_task_library "power_whisperpower"

# rubocop:disable Style/MultilineBlockChain

describe OroGen.power_whisperpower.SmartShuntTask do
    run_live

    attr_reader :task

    before do
        @task = deploy_configure_and_start
    end

    def deploy_configure_and_start
        task = syskit_deploy(
            OroGen.power_whisperpower.SmartShuntTask
                  .deployed_as("task_under_test")
        )
        task.properties.device_id = 5
        syskit_configure_and_start(task)
        task
    end

    it "outputs a full state after receiving a full update" do
        now = Time.now
        status = expect_execution do
            syskit_write(
                task.can_in_port,
                make_read_reply(0x2100, time: now),
                make_read_reply(0x21A0)
            )
        end.to { have_one_new_sample task.full_status_port }

        assert_equal now.tv_sec, status.time.tv_sec
    end

    it "outputs nothing on partial updates" do
        expect_execution do
            syskit_write task.can_in_port, make_read_reply(0x2100)
        end.to { have_no_new_sample task.full_status_port }
    end

    it "ignores CAN messages not for the declared device" do
        expect_execution do
            syskit_write(
                task.can_in_port,
                make_read_reply(0x2100, node_id: 2),
                make_read_reply(0x21A0, node_id: 2)
            )
        end.to { have_no_new_sample task.full_status_port }
    end

    it "ignores messages previously received after a stop/start cycle" do
        expect_execution { syskit_write task.can_in_port, make_read_reply(0x2100) }
            .to { have_no_new_sample task.full_status_port }

        syskit_stop task
        @task = deploy_configure_and_start

        expect_execution { syskit_write task.can_in_port, make_read_reply(0x21A0) }
            .to { have_no_new_sample task.full_status_port }

        expect_execution do
            syskit_write(
                task.can_in_port, make_read_reply(0x2100), make_read_reply(0x21A0)
            )
        end.to { have_one_new_sample task.full_status_port }
    end

    it "handles reconfiguration" do
        expect_execution { syskit_write task.can_in_port, make_read_reply(0x2100) }
            .to { have_no_new_sample task.full_status_port }

        task.needs_reconfiguration!
        syskit_stop task
        @task = deploy_configure_and_start

        expect_execution do
            syskit_write(
                task.can_in_port, make_read_reply(0x2100), make_read_reply(0x21A0)
            )
        end.to { have_one_new_sample task.full_status_port }
    end

    it "outputs the battery status" do
        now = Time.now
        status = expect_execution do
            syskit_write(
                task.can_in_port,
                make_read_reply(0x2100, time: now),
                make_read_reply(0x2112, [45, 0, 0, 0]),
                make_read_reply(0x21A0, [10, 0, 0, 0])
            )
        end.to { have_one_new_sample task.battery_status_port }

        assert_equal now.tv_sec, status.time.tv_sec
        assert_equal 283.15, status.temperature.kelvin
        assert_in_delta 0.45, status.charge
    end

    it "outputs the DC source status" do
        now = Time.now
        status = expect_execution do
            syskit_write(
                task.can_in_port,
                make_read_reply(0x2100, time: now),
                make_read_reply(0x2111, [1, 2, 3, 4]),
                make_read_reply(0x21A0)
            )
        end.to { have_one_new_sample task.battery_dc_output_status_port }

        assert_equal now.tv_sec, status.time.tv_sec
        assert_in_delta 0.258, status.voltage
        assert_in_delta 77.2, status.current
    end

    def make_read_reply(msg_type, data = [0, 0, 0, 0], node_id: 0x15, time: Time.now)
        Types.canbus.Message.new(
            time: time,
            can_id: 0x580 + node_id, # 0x580 + node_id
            size: 8,
            data: [0x43,
                   (msg_type & 0xFF00) >> 8,
                   (msg_type & 0x00FF), 0, *data]
        )
    end
end

# rubocop:enable Style/MultilineBlockChain
