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
    return true;
}
bool PMGGenverterTask::startHook()
{
    if (!PMGGenverterTaskBase::startHook())
        return false;

    m_driver.resetFullUpdate();
    return true;
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

        auto status = m_driver.getStatus();
        _full_status.write(status);
        m_driver.resetFullUpdate();
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
