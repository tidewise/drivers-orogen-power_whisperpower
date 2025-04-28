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
        task.properties.restart_duration = Time.at(0.3)
        syskit_configure_and_start(task)
        task
    end

    it "expects a full_status, a run_time_state and a generator_state sample when " \
       "receiving all messages" do
        expect_execution do
            syskit_write task.control_cmd_port, true
            syskit_write(
                task.can_in_port,
                create_message(0x200),
                create_message(0x201),
                create_message(0x202),
                create_message(0x203),
                create_message(0x204),
                create_message(0x205)
            )
        end.to do
            [
                have_one_new_sample(task.full_status_port),
                have_one_new_sample(task.ac_generator_status_port),
                have_one_new_sample(task.run_time_state_port),
                have_one_new_sample(task.genset_state_port),
                have_one_new_sample(task.can_out_port)
            ]
        end
    end

    it "expects no samples for full_status, run_time_state and generator state ports "\
       "when message 0x205 is not received" do
        expect_execution do
            syskit_write task.control_cmd_port, true

            syskit_write(
                task.can_in_port,
                create_message(0x200),
                create_message(0x201),
                create_message(0x202),
                create_message(0x203),
                create_message(0x204)
            )
        end.to do
            have_no_new_sample task.full_status_port
            have_no_new_sample task.run_time_state_port
            have_no_new_sample task.genset_state_port
            have_one_new_sample(task.can_out_port)
        end
    end

    it "expects a full_status, a run_time_state and a generator state sample when " \
       "only message 0x205 is received" do
        expect_execution do
            syskit_write task.control_cmd_port, true

            syskit_write(
                task.can_in_port,
                create_message(0x205)
            )
        end.to do
            have_one_new_sample task.full_status_port
            have_one_new_sample task.run_time_state_port
            have_one_new_sample task.genset_state_port
            have_one_new_sample(task.can_out_port)
        end
    end

    it "expects full_status to be reset and not output when the message 0x205 is not "\
       "received" do
        expect_execution do
            syskit_write task.control_cmd_port, true

            syskit_write(
                task.can_in_port,
                create_message(0x205)
            )
        end.to { have_one_new_sample task.full_status_port }

        expect_execution do
            syskit_write(
                task.can_in_port,
                create_message(0x203)
            )
        end.to { have_no_new_sample task.full_status_port }
    end

    it "does not send a command if one of the ready to command messages " \
       "were not received (messages with can_id 0x204, 0x205)" do
        expect_execution do
            syskit_write task.control_cmd_port, true
            syskit_write(
                task.can_in_port,
                create_message(0x203)
            )
            syskit_write task.control_cmd_port, true
        end.to { have_no_new_sample(task.can_out_port) }
    end

    it "outputs the restart command before the start command at device startup" do
        outputs = expect_execution do
            syskit_write task.control_cmd_port, true
            syskit_write(
                task.can_in_port,
                create_message(0x201, [0, 5, 0, 0, 0, 0, 0, 0]),
                create_message(0x205)
            )
            sleep 1
        end.to do
            [
                have_one_new_sample(task.can_out_port),
                have_one_new_sample(task.full_status_port),
                have_one_new_sample(task.genset_state_port)
            ]
        end
        expected_state = Types.power_whisperpower.GensetState.new(
            stage: :GENSET_STAGE_RUNNING,
            failure_detected: false
        )
        assert_equal(expected_state, outputs[2])
        assert_equal(outputs[0].data[0], 0)
        assert_equal(outputs[0].data[7], 1)
        outputs = expect_execution do
            syskit_write task.control_cmd_port, true
            syskit_write(
                task.can_in_port,
                create_message(0x201, [0, 5, 0, 0, 0, 0, 0, 0]),
                create_message(0x205)
            )
        end.to do
            [
                have_one_new_sample(task.can_out_port),
                have_one_new_sample(task.full_status_port),
                have_one_new_sample(task.genset_state_port)
            ]
        end
        assert_equal(expected_state, outputs[2])
        assert_equal(outputs[0].data[0], 1)
        assert_equal(outputs[0].data[7], 2)
    end

    it "indicates a failure in the generator state object when there is an alarm" do
        outputs = expect_execution do
            syskit_write task.control_cmd_port, true
            syskit_write(
                task.can_in_port,
                create_message(0x201, [0, 5, 0, 1, 0, 0, 0, 0]),
                create_message(0x204),
                create_message(0x205)
            )
        end.to do
            [
                have_one_new_sample(task.can_out_port),
                have_one_new_sample(task.full_status_port),
                have_one_new_sample(task.genset_state_port)
            ]
        end
        expected_state = Types.power_whisperpower.GensetState.new(
            stage: :GENSET_STAGE_RUNNING,
            failure_detected: true
        )
        assert_equal(expected_state, outputs[2])
    end

    it "ouputs the stopped stage" do
        outputs = expect_execution do
            syskit_write task.control_cmd_port, true
            syskit_write(
                task.can_in_port,
                create_message(0x201, [0, 1, 0, 0, 0, 0, 0, 0]),
                create_message(0x204),
                create_message(0x205)
            )
        end.to do
            [
                have_one_new_sample(task.can_out_port),
                have_one_new_sample(task.full_status_port),
                have_one_new_sample(task.genset_state_port)
            ]
        end
        expected_state = Types.power_whisperpower.GensetState.new(
            stage: :GENSET_STAGE_STOPPED,
            failure_detected: false
        )
        assert_equal(expected_state, outputs[2])
    end

    def create_message(can_id, data = Array.new(8, 0), time: Time.now)
        message = Types.canbus.Message.new(
            time: time,
            can_id: can_id,
            size: 8,
            data: data
        )
        message
    end
end

# rubocop:enable Style/MultilineBlockChain
