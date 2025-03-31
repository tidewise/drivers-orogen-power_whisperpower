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
