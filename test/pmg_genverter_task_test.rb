# frozen_string_literal: true

using_task_library "power_whisperpower"

# rubocop:disable Style/MultilineBlockChain

describe OroGen.power_whisperpower.PMGGenverterTask do
    run_live

    attr_reader :task

    before do
        @task = deploy_configure_and_start
    end

    def deploy_configure_and_start
        task = syskit_deploy(
            OroGen.power_whisperpower.PMGGenverterTask
                  .deployed_as("task_under_test")
        )
        syskit_configure_and_start(task)
        task
    end

    it "expects a sample when receiving all messages" do
        now = rock_now
        status = expect_execution do
            syskit_write(
                task.can_in_port,
                make_read_reply(0x200),
                make_read_reply(0x201),
                make_read_reply(0x202),
                make_read_reply(0x203),
                make_read_reply(0x204),
                make_read_reply(0x205)
            )
        end.to { have_one_new_sample task.full_status_port }

        assert now <= status.time
        assert status.time <= Time.now
    end

    it "expects no sample when message 0x205 is not received" do
        expect_execution do
            syskit_write(
                task.can_in_port,
                make_read_reply(0x200),
                make_read_reply(0x201),
                make_read_reply(0x202),
                make_read_reply(0x203),
                make_read_reply(0x204)
            )
        end.to { have_no_new_sample task.full_status_port }
    end

    it "expects a sample when only message 0x205 is received" do
        expect_execution do
            syskit_write(
                task.can_in_port,
                make_read_reply(0x205)
            )
        end.to { have_one_new_sample task.full_status_port }
    end

    it "expects full update to be reset when writing a message other than 0x205" do
        expect_execution do
            syskit_write(
                task.can_in_port,
                make_read_reply(0x205)
            )
        end.to { have_one_new_sample task.full_status_port }

        expect_execution do
            syskit_write(
                task.can_in_port,
                make_read_reply(0x203)
            )
        end.to { have_no_new_sample task.full_status_port }
    end

    it "does not send a command if one of the ready to command messages " \
       "were not received (messages with can_id 0x204, 0x205)" do
        expect_execution do
            syskit_write task.control_cmd_port, true
        end.to { have_no_new_sample(task.can_out_port, at_least_during: 1) }

        expect_execution.to do
            have_no_new_sample(task.can_out_port, at_least_during: 1)
        end
    end

    it "sends a NO COMMAND message for 30ms before sending the command" do
        expect_execution do
            syskit_write(
                task.can_in_port,
                make_read_reply(0x205)
            )
        end.to { have_one_new_sample task.full_status_port }

        no_command = expect_execution do
            syskit_write task.control_cmd_port, true
        end.to do
            have_one_new_sample(task.can_out_port)
                .matching { |s| no_command(s) }
        end

        command = expect_execution.to do
            have_one_new_sample(task.can_out_port)
                .matching { |s| enable_generation(s) }
        end

        assert no_command.time <= command.time
        assert_in_delta(
            (command.time - no_command.time),
            0.03,
            1e-2
        )
    end

    def enable_generation(sample)
        sample.data[0] == 1 && sample.data[1] == 0
    end

    def disable_generation(sample)
        sample.data[0] == 0 && sample.data[1] == 1
    end

    def no_command(sample)
        sample.data[0] == 0 && sample.data[1] == 0
    end

    def rock_now
        now = Time.now
        Time.at(now.tv_sec, now.tv_usec / 1000, :millisecond)
    end

    def make_read_reply(msg_type, data = Array.new(8, 0), time: Time.now)
        message = Types.canbus.Message.new(
            time: time,
            can_id: msg_type,
            size: 8,
            data: data
        )
        message
    end
end

# rubocop:enable Style/MultilineBlockChain
