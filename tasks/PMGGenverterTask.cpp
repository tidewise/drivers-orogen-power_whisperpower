/* Generated from orogen/lib/orogen/templates/tasks/Task.cpp */

#include "PMGGenverterTask.hpp"

using namespace power_whisperpower;

PMGGenverterTask::PMGGenverterTask(std::string const& name)
    : PMGGenverterTaskBase(name)
{
}

PMGGenverterTask::~PMGGenverterTask()
{
}

/// The following lines are template definitions for the various state machine
// hooks defined by Orocos::RTT. See PMGGenverterTask.hpp for more detailed
// documentation about them.

bool PMGGenverterTask::configureHook()
{
    if (!PMGGenverterTaskBase::configureHook())
        return false;

    m_driver = PMGGenverter();
    m_ready_to_command = false;
    return true;
}
bool PMGGenverterTask::startHook()
{
    if (!PMGGenverterTaskBase::startHook())
        return false;

    m_driver.resetFullUpdate();
    m_last_command = false;
    return true;
}

GeneratorState power_whisperpower::PMGGenverterTask::getGeneratorState(
    PMGGenverterStatus const& status)
{
    uint8_t running_state = PMGGenverterStatus::Status::GENERATION_ENABLED |
                            PMGGenverterStatus::Status::ENGINE_ENABLED;
    if ((status.status & running_state) == running_state) {
        return GeneratorState::RUNNING;
    }
    else if (!(PMGGenverterStatus::Status::GENERATION_ENABLED & status.status)) {
        return GeneratorState::STOPPED;
    }
    else {
        return GeneratorState::FAILURE;
    }
}
void PMGGenverterTask::updateHook()
{
    PMGGenverterTaskBase::updateHook();

    canbus::Message can_in;
    while (_can_in.read(can_in, false) == RTT::NewData) {
        m_driver.process(can_in);

        if (!m_driver.hasFullUpdate()) {
            continue;
        }

        if (can_in.can_id == 0x204 || can_in.can_id == 0x205) {
            m_ready_to_command = true;
        }

        auto status = m_driver.getStatus();
        auto generator_state = getGeneratorState(status);
        _generator_state.write(generator_state);
        _full_status.write(status);
        auto run_time_state = m_driver.getRunTimeState();
        _run_time_state.write(run_time_state);
        m_driver.resetFullUpdate();
    }

    bool control_cmd;
    if (_control_cmd.read(control_cmd) != RTT::NewData) {
        return;
    }
    if (m_ready_to_command) {
        handleControlCommand(control_cmd);
    }
}
void PMGGenverterTask::handleControlCommand(bool control_cmd)
{
    if (control_cmd) {
        if (control_cmd != m_last_command) {
            m_restart_command_deadline =
                base::Time::now() + base::Time::fromMilliseconds(250);
            m_last_command = control_cmd;
        }
        if (base::Time::now() <= m_restart_command_deadline) {
            _can_out.write(m_driver.queryGeneratorCommand(false, false));
        }
        else {
            _can_out.write(m_driver.queryGeneratorCommand(true, false));
        }
    }
    else {
        _can_out.write(m_driver.queryGeneratorCommand(false, true));
        m_last_command = control_cmd;
    }
}
void PMGGenverterTask::errorHook()
{
    PMGGenverterTaskBase::errorHook();
}
void PMGGenverterTask::stopHook()
{
    PMGGenverterTaskBase::stopHook();
}
void PMGGenverterTask::cleanupHook()
{
    PMGGenverterTaskBase::cleanupHook();
}
