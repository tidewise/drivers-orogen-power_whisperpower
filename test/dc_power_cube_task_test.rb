# frozen_string_literal: true

using_task_library "power_whisperpower"

# rubocop:disable Style/MultilineBlockChain

describe OroGen.power_whisperpower.DCPowerCubeTask do
    run_live

    attr_reader :task

    before do
        @task = deploy_configure_and_start
    end

    def deploy_configure_and_start
        task = syskit_deploy(
            OroGen.power_whisperpower.DCPowerCubeTask
                  .deployed_as("task_under_test")
        )
        task.properties.device_id = 5
        syskit_configure_and_start(task)
        task
    end

    it "outputs a full state after receiving a full update" do
        now = rock_now
        status = expect_execution do
            syskit_write(
                task.can_in_port,
                make_read_reply(0x2100, [0, 0, 0, 0]),
                make_read_reply(0x21A0, [0, 0, 0, 0])
            )
        end.to { have_one_new_sample task.full_status_port }

        assert now <= status.time
        assert status.time <= Time.now
    end

    it "outputs nothing on partial updates" do
        expect_execution do
            syskit_write(
                task.can_in_port, make_read_reply(0x2100, [0, 0, 0, 0])
            )
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

    it "outputs the generator status even if the generator is not present" do
        before = rock_now
        sample = expect_execution do
            syskit_write(
                task.can_in_port, make_read_reply(0x2100), make_read_reply(0x21A0)
            )
        end.to { have_one_new_sample task.ac_generator_status_port }

        assert_operator before, :<=, sample.time
        assert_operator sample.time, :<, Time.now
        assert sample.time <= Time.now
        assert_equal 0, sample.frequency
        assert_equal 0, sample.generator_rotational_velocity
    end

    it "outputs the generator status if the generator is present" do
        now = rock_now
        sample = expect_execution do
            syskit_write(
                task.can_in_port,
                make_read_reply(0x2100, [128, 0, 0, 0]),
                make_read_reply(0x2112, [0, 100, 0, 50]),
                make_read_reply(0x21A0)
            )
        end.to { have_one_new_sample task.ac_generator_status_port }

        assert now <= sample.time
        assert sample.time <= Time.now
        assert_equal 100, sample.frequency
        assert_in_delta 50 * 60 * 2 * Math::PI, sample.generator_rotational_velocity
    end

    it "outputs the grid status even if the grid is not present" do
        before = rock_now
        sample = expect_execution do
            syskit_write(
                task.can_in_port, make_read_reply(0x2100), make_read_reply(0x21A0)
            )
        end.to { have_one_new_sample task.ac_grid_status_port }

        assert_operator before, :<=, sample.time
        assert_operator sample.time, :<, Time.now
        assert sample.time <= Time.now
        assert_equal 0, sample.voltage
        assert_equal 0, sample.current
    end

    it "outputs the grid status if the grid is present" do
        now = rock_now
        sample = expect_execution do
            syskit_write(
                task.can_in_port,
                make_read_reply(0x2100, [64, 0, 0, 0]),
                make_read_reply(0x2111, [1, 20, 10, 50]),
                make_read_reply(0x21A0)
            )
        end.to { have_one_new_sample task.ac_grid_status_port }

        assert now <= sample.time
        assert sample.time <= Time.now
        assert sample.frequency.nan?
        assert_in_delta 276, sample.voltage
        assert_in_delta 10, sample.current
    end

    it "outputs the DC output status" do
        now = rock_now
        sample = expect_execution do
            syskit_write(
                task.can_in_port,
                make_read_reply(0x2100),
                make_read_reply(0x2152, [1, 20, 10, 50]),
                make_read_reply(0x2153, [2, 5, 10, 50]),
                make_read_reply(0x21A0)
            )
        end.to { have_one_new_sample task.dc_output_status_port }

        assert now <= sample.time
        assert sample.time <= Time.now
        assert_in_delta 0.276, sample.voltage
        assert_in_delta 517, sample.current
        assert_in_delta 2_610, sample.max_current
    end

    def rock_now
        now = Time.now
        Time.at(now.tv_sec, now.tv_usec / 1000, :millisecond)
    end

    def make_read_reply(msg_type, data = [0, 0, 0, 0], node_id: 0x35, time: Time.now)
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
