/* Generated from orogen/lib/orogen/templates/tasks/Task.cpp */

#include "SmartShuntTask.hpp"

using namespace power_base;
using namespace power_whisperpower;

SmartShuntTask::SmartShuntTask(std::string const& name)
    : SmartShuntTaskBase(name)
    , m_driver(0)
{
}

SmartShuntTask::~SmartShuntTask()
{
}

bool SmartShuntTask::configureHook()
{
    if (! SmartShuntTaskBase::configureHook()) {
        return false;
    }

    m_driver = SmartShunt(_device_id.get());
    return true;
}
bool SmartShuntTask::startHook()
{
    if (! SmartShuntTaskBase::startHook()) {
        return false;
    }
    m_driver.resetFullUpdate();
    return true;
}
static BatteryStatus toBatteryStatus(SmartShuntStatus const& status) {
    BatteryStatus ret;
    ret.time = status.time;
    ret.temperature = status.temperature_bts;
    ret.charge = status.battery_charge;
    return ret;
}
static DCSourceStatus toDCSourceStatus(SmartShuntStatus const& status) {
    DCSourceStatus ret;
    ret.time = status.time;
    ret.voltage = status.battery_voltage;
    ret.current = status.shunt_current;
    return ret;
}
void SmartShuntTask::updateHook()
{
    SmartShuntTaskBase::updateHook();

    canbus::Message can_in;
    while (_can_in.read(can_in, false) == RTT::NewData) {
        m_driver.process(can_in);

        if (!m_driver.hasFullUpdate()) {
            continue;
        }

        auto status = m_driver.getStatus();
        _full_status.write(status);
        m_driver.resetFullUpdate();

        _battery_status.write(toBatteryStatus(status));
        _battery_dc_output_status.write(toDCSourceStatus(status));
    }
}
void SmartShuntTask::errorHook()
{
    SmartShuntTaskBase::errorHook();
}
void SmartShuntTask::stopHook()
{
    SmartShuntTaskBase::stopHook();
}
void SmartShuntTask::cleanupHook()
{
    SmartShuntTaskBase::cleanupHook();
}
