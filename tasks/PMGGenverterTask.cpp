/* Generated from orogen/lib/orogen/templates/tasks/Task.cpp */

#include "PMGGenverterTask.hpp"
#include <power_base/ACSourceStatus.hpp>

using namespace power_whisperpower;

PMGGenverterTask::PMGGenverterTask(std::string const& name)
    : PMGGenverterTaskBase(name)
{
    _restart_duration.set(base::Time::fromMilliseconds(500));
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
    m_restart_duration = _restart_duration.get();
    return true;
}
bool PMGGenverterTask::startHook()
{
    if (!PMGGenverterTaskBase::startHook())
        return false;

    m_driver = PMGGenverter();
    m_last_command = false;
    return true;
}
static GensetState getGensetState(PMGGenverterStatus const& status)
{
    GensetState generator_state;
    if (status.engine_alarm || status.inverter_alarm) {
        generator_state.failure_detected = true;
    }
    uint8_t running_state = PMGGenverterStatus::Status::GENERATION_ENABLED |
                            PMGGenverterStatus::Status::ENGINE_ENABLED;
    if ((status.status & running_state) == running_state) {
        generator_state.stage = GensetState::Stage::GENSET_STAGE_RUNNING;
    }
    else {
        generator_state.stage = GensetState::Stage::GENSET_STAGE_STOPPED;
    }
    return generator_state;
}
static power_base::ACSourceStatus getACStatus(PMGGenverterStatus const& status)
{
    power_base::ACSourceStatus ac_status;
    ac_status.time = status.time;
    ac_status.current = status.ac_current;
    ac_status.voltage = status.ac_voltage;
    return ac_status;
}
void PMGGenverterTask::writeStates()
{
    auto status = m_driver.getStatus();
    auto generator_state = getGensetState(status);
    _genset_state.write(generator_state);
    auto ac_status = getACStatus(status);
    _ac_status.write(ac_status);
    _full_status.write(status);
    auto run_time_state = m_driver.getRunTimeState();
    _run_time_state.write(run_time_state);
}
void PMGGenverterTask::updateHook()
{
    PMGGenverterTaskBase::updateHook();

    canbus::Message can_in;
    while (_can_in.read(can_in, false) == RTT::NewData) {
        m_driver.process(can_in);
        if (can_in.can_id == 0x204 || can_in.can_id == 0x205) {
            handleControlCommand();
        }
        if (!m_driver.hasFullUpdate()) {
            continue;
        }
        writeStates();
        m_driver.resetFullUpdate();
    }
}
void PMGGenverterTask::handleControlCommand()
{
    bool control_cmd;
    if (_control_cmd.read(control_cmd) == RTT::NoData) {
        return;
    }
    if (!control_cmd) {
        _can_out.write(m_driver.queryGeneratorCommand(false, true));
        m_last_command = control_cmd;
        return;
    }
    if (!m_last_command) {
        m_restart_command_deadline = base::Time::now() + m_restart_duration;
        m_last_command = true;
    }
    if (base::Time::now() <= m_restart_command_deadline) {
        _can_out.write(m_driver.queryGeneratorCommand(false, false));
    }
    else {
        _can_out.write(m_driver.queryGeneratorCommand(true, false));
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
