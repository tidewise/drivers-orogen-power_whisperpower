/* Generated from orogen/lib/orogen/templates/tasks/Task.cpp */

#include "DCPowerCubeTask.hpp"

using namespace power_whisperpower;
using namespace power_base;

DCPowerCubeTask::DCPowerCubeTask(std::string const& name)
    : DCPowerCubeTaskBase(name)
    , m_driver(1)
{
}

DCPowerCubeTask::~DCPowerCubeTask()
{
}

bool DCPowerCubeTask::configureHook()
{
    if (! DCPowerCubeTaskBase::configureHook()) {
        return false;
    }

    m_driver = DCPowerCube(_device_id.get());
    return true;
}
bool DCPowerCubeTask::startHook()
{
    if (! DCPowerCubeTaskBase::startHook()) {
        return false;
    }
    m_driver.resetFullUpdate();
    return true;
}

static ACSourceStatus toACGridStatus(DCPowerCubeStatus const& status) {
    ACSourceStatus ret;
    ret.time = status.time;
    ret.voltage = status.grid_voltage;
    ret.current = status.grid_current;
    return ret;
}
static ACGeneratorStatus toACGeneratorStatus(DCPowerCubeStatus const& status) {
    ACGeneratorStatus ret;
    ret.time = status.time;
    ret.frequency = status.generator_frequency;
    ret.generator_rotational_velocity = status.generator_rotational_velocity;
    return ret;
}
static DCSourceStatus toDCSourceStatus(DCPowerCubeStatus const& status) {
    DCSourceStatus ret;
    ret.time = status.time;
    ret.voltage = status.dc_output_voltage;
    ret.current = status.dc_output_current;
    ret.max_current = status.dc_output_current_limit;
    return ret;
}

void DCPowerCubeTask::updateHook()
{
    DCPowerCubeTaskBase::updateHook();

    canbus::Message can_in;
    while (_can_in.read(can_in, false) == RTT::NewData) {
        m_driver.process(can_in);

        if (!m_driver.hasFullUpdate()) {
            continue;
        }

        auto status = m_driver.getStatus();
        _full_status.write(status);
        m_driver.resetFullUpdate();

        if (status.status & DCPowerCubeStatus::STATUS_GENERATOR_PRESENT) {
            _ac_generator_status.write(toACGeneratorStatus(status));
        }
        if (status.status & DCPowerCubeStatus::STATUS_GRID_PRESENT) {
            _ac_grid_status.write(toACGridStatus(status));
        }
        _dc_output_status.write(toDCSourceStatus(status));
    }
}
void DCPowerCubeTask::errorHook()
{
    DCPowerCubeTaskBase::errorHook();
}
void DCPowerCubeTask::stopHook()
{
    DCPowerCubeTaskBase::stopHook();
}
void DCPowerCubeTask::cleanupHook()
{
    DCPowerCubeTaskBase::cleanupHook();
}
