// SPDX-License-Identifier: Apache-2.0
//
// AIDL IBootControl for this recovery. fastbootd blocks in WaitForService
// until this instance is registered. The service answers from
// ro.boot.slot_suffix and does not open a block device.
//
// Slot B of this unit is erased. MediaTek's preloader honors the boot_ctrl
// struct in misc, so a write there can change the slot that boots. This
// process never writes that struct and never calls SetBootRegionSlot.

#include <aidl/android/hardware/boot/BnBootControl.h>
#include <android-base/logging.h>
#include <android-base/properties.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>

#include <string>

using aidl::android::hardware::boot::BnBootControl;
using aidl::android::hardware::boot::IBootControl;
using aidl::android::hardware::boot::MergeStatus;
using ndk::ScopedAStatus;

namespace {

// Kept referenced so pack-debug-vendor-boot.sh can see it in the binary.
static const char kMarker[] = "YZL boot control: slot A only, no partition write";

constexpr int32_t kSlotA = 0;
constexpr int32_t kSlotB = 1;
constexpr int32_t kSlotCount = 2;

int32_t CurrentSlot() {
    const std::string suffix = android::base::GetProperty("ro.boot.slot_suffix", "");
    if (suffix.empty() || suffix == "_a") {
        if (suffix.empty()) {
            LOG(WARNING) << "ro.boot.slot_suffix is empty; reporting slot A";
        }
        return kSlotA;
    }
    LOG(ERROR) << "ro.boot.slot_suffix is '" << suffix
               << "'; slot B is erased on this unit";
    return kSlotB;
}

bool KnownSlot(int32_t slot) {
    return slot == kSlotA || slot == kSlotB;
}

ScopedAStatus InvalidSlot(int32_t slot) {
    const std::string message = "Invalid slot " + std::to_string(slot);
    return ScopedAStatus::fromServiceSpecificErrorWithMessage(IBootControl::INVALID_SLOT,
                                                              message.c_str());
}

ScopedAStatus Failed(const char* message) {
    return ScopedAStatus::fromServiceSpecificErrorWithMessage(IBootControl::COMMAND_FAILED,
                                                              message);
}

class YzlBootControl : public BnBootControl {
  public:
    explicit YzlBootControl(int32_t slot) : slot_(slot), merge_(MergeStatus::NONE) {}

    ScopedAStatus getActiveBootSlot(int32_t* out) override {
        *out = slot_;
        return ScopedAStatus::ok();
    }

    ScopedAStatus getCurrentSlot(int32_t* out) override {
        *out = slot_;
        return ScopedAStatus::ok();
    }

    ScopedAStatus getNumberSlots(int32_t* out) override {
        *out = kSlotCount;
        return ScopedAStatus::ok();
    }

    ScopedAStatus getSnapshotMergeStatus(MergeStatus* out) override {
        *out = merge_;
        return ScopedAStatus::ok();
    }

    ScopedAStatus getSuffix(int32_t slot, std::string* out) override {
        if (slot == kSlotA) {
            *out = "_a";
        } else if (slot == kSlotB) {
            *out = "_b";
        } else {
            out->clear();
        }
        return ScopedAStatus::ok();
    }

    ScopedAStatus isSlotBootable(int32_t slot, bool* out) override {
        if (!KnownSlot(slot)) return InvalidSlot(slot);
        // Slot B has no boot chain. Report it unbootable so fastboot will
        // not treat it as a fallback.
        *out = slot == kSlotA;
        return ScopedAStatus::ok();
    }

    ScopedAStatus isSlotMarkedSuccessful(int32_t slot, bool* out) override {
        if (!KnownSlot(slot)) return InvalidSlot(slot);
        *out = slot == kSlotA && slot_ == kSlotA;
        return ScopedAStatus::ok();
    }

    ScopedAStatus markBootSuccessful() override {
        LOG(INFO) << "markBootSuccessful ignored; misc is not written";
        return ScopedAStatus::ok();
    }

    ScopedAStatus setActiveBootSlot(int32_t slot) override {
        if (!KnownSlot(slot)) return InvalidSlot(slot);
        if (slot == kSlotB) {
            LOG(ERROR) << "refusing setActiveBootSlot(1); slot B is erased";
            return Failed("slot B is erased on this unit");
        }
        if (slot_ != kSlotA) {
            LOG(ERROR) << "refusing setActiveBootSlot(0); current slot is not A";
            return Failed("current slot is not A");
        }
        LOG(INFO) << "setActiveBootSlot(0) no-op; misc is not written";
        return ScopedAStatus::ok();
    }

    ScopedAStatus setSlotAsUnbootable(int32_t slot) override {
        if (!KnownSlot(slot)) return InvalidSlot(slot);
        if (slot == kSlotA) {
            LOG(ERROR) << "refusing setSlotAsUnbootable(0)";
            return Failed("refusing to mark slot A unbootable");
        }
        LOG(INFO) << "setSlotAsUnbootable(1) no-op; slot B is already unbootable";
        return ScopedAStatus::ok();
    }

    ScopedAStatus setSnapshotMergeStatus(MergeStatus status) override {
        // Remembered for this process only. Persisting it would write misc.
        LOG(INFO) << "setSnapshotMergeStatus " << static_cast<int32_t>(status)
                  << " kept in memory";
        merge_ = status;
        return ScopedAStatus::ok();
    }

  private:
    const int32_t slot_;
    MergeStatus merge_;
};

}  // namespace

int main(int, char** argv) {
    android::base::InitLogging(argv, android::base::KernelLogger);
    const int32_t slot = CurrentSlot();
    LOG(INFO) << kMarker << " current=" << slot;

    ABinderProcess_setThreadPoolMaxThreadCount(0);
    std::shared_ptr<YzlBootControl> service = ndk::SharedRefBase::make<YzlBootControl>(slot);
    const std::string instance = std::string(IBootControl::descriptor) + "/default";
    const binder_status_t status =
            AServiceManager_addService(service->asBinder().get(), instance.c_str());
    if (status != STATUS_OK) {
        LOG(ERROR) << "Failed to register " << instance << " status " << status;
        return 1;
    }
    ABinderProcess_joinThreadPool();
    return 1;
}
