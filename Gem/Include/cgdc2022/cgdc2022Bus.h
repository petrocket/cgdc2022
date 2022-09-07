
#pragma once

#include <AzCore/EBus/EBus.h>
#include <AzCore/Interface/Interface.h>
#include <AzCore/Math/Vector3.h>
#include <AzCore/Serialization/SerializeContext.h>
#include <AzCore/RTTI/BehaviorContext.h>

namespace cgdc2022
{
    class LevelTile final
    {
    public:
        AZ_CLASS_ALLOCATOR(LevelTile, AZ::SystemAllocator, 0);
        AZ_RTTI(LevelTile, "{C0CA11BD-8721-4CF8-8819-43F2FC5E0272}");
        static void Reflect(AZ::ReflectContext* context);

        AZ::Vector3 m_position;
        AZStd::string m_type;
    };

    class LevelData final
    {
    public:
        AZ_CLASS_ALLOCATOR(LevelData, AZ::SystemAllocator, 0);
        AZ_RTTI(LevelData, "{6DF59AFF-0211-4AB1-88BC-84AF7D26EFD1}");
        static void Reflect(AZ::ReflectContext* context);

        //! Name of the game options save data file.
        static constexpr const char* SaveDataBufferName = "LevelData";

        //! Default values
        static constexpr const char* DefaultLevelName = "LevelName";
        static constexpr const char* DefaultLevelDisplayName = "Level Name";

        //! Called when loaded from persistent data.
        void OnLoadedFromPersistentData();

    private:
        AZStd::string m_levelName = DefaultLevelName;
        AZStd::string m_levelDisplayName = DefaultLevelDisplayName;
        AZStd::vector<LevelTile> m_tiles;
    };

    inline void LevelTile::Reflect(AZ::ReflectContext* context)
    {
        if (AZ::SerializeContext* serializeContext = azrtti_cast<AZ::SerializeContext*>(context))
        {
                serializeContext->Class<LevelTile>()
                ->Version(1)
                ->Field("Type", &LevelTile::m_type)
                ->Field("Position", &LevelTile::m_position)
                ;
        }

        AZ::BehaviorContext* behaviorContext = azrtti_cast<AZ::BehaviorContext*>(context);
        if (behaviorContext)
        {
            behaviorContext->Class<LevelTile>()
                //->Constructor<LevelTile&>()
                ->Attribute(AZ::Script::Attributes::Storage, AZ::Script::Attributes::StorageType::Value)
                ->Property("type", BehaviorValueProperty(&LevelTile::m_type))
                ->Property("position", BehaviorValueProperty(&LevelTile::m_position));
        }
    }

    inline void LevelData::Reflect(AZ::ReflectContext* context)
    {
        LevelTile::Reflect(context);

        if (AZ::SerializeContext* serializeContext = azrtti_cast<AZ::SerializeContext*>(context))
        {
            serializeContext->Class<LevelData>()
                ->Version(1)
                ->Field("LevelName", &LevelData::m_levelName)
                ->Field("Tiles", &LevelData::m_tiles)
                ;
        }

        AZ::BehaviorContext* behaviorContext = azrtti_cast<AZ::BehaviorContext*>(context);
        if (behaviorContext)
        {
            behaviorContext->Class<LevelData>()
                ->Attribute(AZ::Script::Attributes::Storage, AZ::Script::Attributes::StorageType::Value)
                ->Property("name", BehaviorValueProperty(&LevelData::m_levelName))
                ->Property("tiles", BehaviorValueProperty(&LevelData::m_tiles));
        }
    }


    class cgdc2022Requests
    {
    public:
        AZ_RTTI(cgdc2022Requests, "{12C17680-1A64-4634-BBA8-8A4623862D8C}");
        virtual ~cgdc2022Requests() = default;

        virtual void LoadLevel(const AZStd::string& levelName) = 0;
        virtual void SaveLevel(const AZStd::string& levelName, const LevelData& levelData) = 0;
    };

    class cgdc2022BusTraits
        : public AZ::EBusTraits
    {
    public:
        // EBusTraits overrides
        static constexpr AZ::EBusHandlerPolicy HandlerPolicy = AZ::EBusHandlerPolicy::Single;
        static constexpr AZ::EBusAddressPolicy AddressPolicy = AZ::EBusAddressPolicy::Single;
    };

    using cgdc2022RequestBus = AZ::EBus<cgdc2022Requests, cgdc2022BusTraits>;
    using cgdc2022Interface = AZ::Interface<cgdc2022Requests>;

    class cgdc2022Notifications : public AZ::EBusTraits
    {
    public:
        //! EBus Trait: save data notifications are addressed to a single address
        static const AZ::EBusAddressPolicy AddressPolicy = AZ::EBusAddressPolicy::Single;

        //! EBus Trait: save data notifications can be handled by multiple listeners
        static const AZ::EBusHandlerPolicy HandlerPolicy = AZ::EBusHandlerPolicy::Multiple;

        virtual void OnLevelLoaded(LevelData levelData) = 0;
    };
    using cgdc2022NotificationBus = AZ::EBus<cgdc2022Notifications>;
} // namespace cgdc2022
