#include <iostream>
#include <string>
#include <future>
#include <thread>
#include <chrono>

#include <mavsdk/mavsdk.h>
#include <mavsdk/plugins/telemetry/telemetry.h>
#include <mavsdk/plugins/calibration/calibration.h>
#include <mavsdk/plugins/mavlink_passthrough/mavlink_passthrough.h>
#include <mavsdk/mavlink/common/mavlink.h>
#include <mavsdk/log_callback.h>


std::string get_udp_info() {
	const std::string udp_ip = "127.0.0.1";
	const std::string udp_port = "14550";
	const std::string udp_full_ip = udp_ip +":"+ udp_port;
	return udp_full_ip;
}


bool connect_udp(mavsdk::Mavsdk& mavsdk, const std::string& udp_full_ip) {
	std::cout << "Connecting through udp://" << udp_full_ip << std::endl;

    const std::string connection_url = "udpin://" + udp_full_ip;
    mavsdk::ConnectionResult connection_result = mavsdk.add_any_connection(connection_url);

    if (connection_result != mavsdk::ConnectionResult::Success) {
        std::cerr << "Invalid connection: " << connection_result  << std::endl;
        return false;
    }
	return true;
}


std::shared_ptr<mavsdk::System> wait_for_system(mavsdk::Mavsdk& mavsdk){
	std::cout << "Waiting for system..." << std::endl;
	
	auto system_promise = std::promise<std::shared_ptr<mavsdk::System>>();
	auto system_future = system_promise.get_future();

	mavsdk.subscribe_on_new_system([&mavsdk, &system_promise]() {
		const auto new_system = mavsdk.systems().back();

		if (new_system->is_connected()) {
			std::cout << "System is connected!\n" << std::endl;
			system_promise.set_value(new_system);
		}
	});
	return system_future.get(); // blocking until drone is connected
}


std::string map_flight_mode(mavsdk::Telemetry::FlightMode flight_mode) {
    switch (flight_mode) {
        case mavsdk::Telemetry::FlightMode::Unknown:		return "Unknown";
        case mavsdk::Telemetry::FlightMode::Ready:			return "Ready";
        case mavsdk::Telemetry::FlightMode::Takeoff:		return "Takeoff";
        case mavsdk::Telemetry::FlightMode::Hold:			return "Hold";
        case mavsdk::Telemetry::FlightMode::Mission:		return "Mission";
        case mavsdk::Telemetry::FlightMode::ReturnToLaunch:	return "ReturnToLaunch";
        case mavsdk::Telemetry::FlightMode::Land:			return "Land";
        case mavsdk::Telemetry::FlightMode::Offboard:		return "Offboard";
        case mavsdk::Telemetry::FlightMode::FollowMe:		return "FollowMe";
        case mavsdk::Telemetry::FlightMode::Manual:			return "Manual";
        case mavsdk::Telemetry::FlightMode::Altctl:			return "Altctl";
        case mavsdk::Telemetry::FlightMode::Posctl:			return "Posctl";
        case mavsdk::Telemetry::FlightMode::Acro:			return "Acro";
        case mavsdk::Telemetry::FlightMode::Stabilized:		return "Stabilized";
        case mavsdk::Telemetry::FlightMode::Rattitude:		return "Rattitude";
        default:											return "Unknown; a new mode?";
	}
}	


std::string map_cal_status(uint8_t status) {
    switch (status) {
        case 0: return "MAG_CAL_NOT_STARTED";
        case 1: return "MAG_CAL_WAITING_TO_START";
        case 2: return "MAG_CAL_RUNNING_STEP_ONE";
        case 3: return "MAG_CAL_RUNNING_STEP_TWO";
        case 4: return "MAG_CAL_SUCCESS";
		case 5: return "MAG_CAL_FAILED";
		case 6: return "MAG_CAL_BAD_ORIENTATION";
		case 7: return "MAG_CAL_BAD_RADIUS";
		default: return "UNKNOWN_STATUS";
    }
}


void loop(){
	//std::cout << "[debug] Entering loop..." << std::endl;
	while (true) {
		std::this_thread::sleep_for(std::chrono::seconds(1));
	}
}


int main() {
	// Get udp ip & port
	std::string udp_full_ip = get_udp_info();

	const mavsdk::Mavsdk::Configuration config{mavsdk::ComponentType::GroundStation};
	mavsdk::Mavsdk mavsdk{config};
	
	// Ignore MAVSDK debug, info & warning log messages
	mavsdk::log::subscribe([](mavsdk::log::Level level,
							  const std::string& message,
							  const std::string& file,
							  int line) {
			return (level < mavsdk::log::Level::Err);
	});

	// Connect through UDP
	if (!connect_udp(mavsdk, udp_full_ip)) {
		return 1;
	}

	// Wait for drone
	const auto system = wait_for_system(mavsdk);
	
	// Subscribe to Flight modes
	mavsdk::Telemetry telemetry{system};
	telemetry.subscribe_flight_mode([](mavsdk::Telemetry::FlightMode flight_mode) {
		static mavsdk::Telemetry::FlightMode last_mode = mavsdk::Telemetry::FlightMode::Unknown;
		if (flight_mode != last_mode) {
			std::cout << "Flight mode " << static_cast<int>(flight_mode) << ": " << map_flight_mode(flight_mode) << "\n";
			last_mode = flight_mode;
		}	
	});
	
	// Subscribe to MAG_CAL_REPORT packages
	auto passthrough_192 = std::make_shared<mavsdk::MavlinkPassthrough>(system);
	passthrough_192->subscribe_message(192, [](const mavlink_message_t& msg) {
		static mavlink_mag_cal_report_t last_report{.compass_id = UINT8_MAX};
		mavlink_mag_cal_report_t report;
		mavlink_msg_mag_cal_report_decode(&msg, &report);
		
		if (report.compass_id != last_report.compass_id || report.cal_status != last_report.cal_status) {
			last_report = report;
			std::cout << "\nReceived MAG_CAL_REPORT packet (ID 192)" << std::endl;
			std::cout << "Compass ID: " << static_cast<int>(report.compass_id) << std::endl;
			std::cout << "Status " << static_cast<int>(report.cal_status) << ": " << map_cal_status(report.cal_status) << std::endl;
			std::cout << "Fitness: " << static_cast<int>(report.fitness) << std::endl;
		}
	});

	// Subscribe to MAG_CAL_PROGRESS packages
	auto passthrough_191 = std::make_shared<mavsdk::MavlinkPassthrough>(system);
    passthrough_191->subscribe_message(191, [](const mavlink_message_t& msg) {
		static mavlink_mag_cal_report_t last_report{.compass_id = UINT8_MAX};
		mavlink_mag_cal_report_t report;
		mavlink_msg_mag_cal_report_decode(&msg, &report);
		
		if (report.compass_id != last_report.compass_id || report.cal_status != last_report.cal_status) {
			last_report = report;
			std::cout << "\nReceived MAG_CAL_PROGRESS packet (ID 191)" << std::endl;
			std::cout << "Compass ID: " << static_cast<int>(report.compass_id) << std::endl;
			std::cout << "Status " << static_cast<int>(report.cal_status) << ": " << map_cal_status(report.cal_status) << std::endl;
			std::cout << "Fitness: " << static_cast<int>(report.fitness) << std::endl;
		}
	});
		
	// Subscribe to compass cal data via MAVSDK
	// NOTE: Ardupilot SITL does NOT send this data
	mavsdk::Calibration calibration{system};    
	calibration.calibrate_magnetometer_async(
        [](mavsdk::Calibration::Result result, mavsdk::Calibration::ProgressData progress_data) {
			if (progress_data.has_status_text) {
				std::cout << "Compass calibration status: " << progress_data.status_text << "\n";
			}
			if (progress_data.has_progress) {
				std::cout << "Compass calibration progress: " << progress_data.progress*100 << "%\n";
			}
		}
	);
	
	loop();
	return 0;
}
