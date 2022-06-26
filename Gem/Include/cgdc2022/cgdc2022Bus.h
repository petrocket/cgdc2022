
#pragma once

#include <AzCore/EBus/EBus.h>
#include <AzCore/Interface/Interface.h>

namespace cgdc2022
{
    class cgdc2022Requests
    {
    public:
        AZ_RTTI(cgdc2022Requests, "{12C17680-1A64-4634-BBA8-8A4623862D8C}");
        virtual ~cgdc2022Requests() = default;
        // Put your public methods here
    };

    class cgdc2022BusTraits
        : public AZ::EBusTraits
    {
    public:
        //////////////////////////////////////////////////////////////////////////
        // EBusTraits overrides
        static constexpr AZ::EBusHandlerPolicy HandlerPolicy = AZ::EBusHandlerPolicy::Single;
        static constexpr AZ::EBusAddressPolicy AddressPolicy = AZ::EBusAddressPolicy::Single;
        //////////////////////////////////////////////////////////////////////////
    };

    using cgdc2022RequestBus = AZ::EBus<cgdc2022Requests, cgdc2022BusTraits>;
    using cgdc2022Interface = AZ::Interface<cgdc2022Requests>;

} // namespace cgdc2022
