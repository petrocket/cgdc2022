
#include <AzCore/Serialization/SerializeContext.h>
#include <AzCore/Serialization/EditContext.h>
#include <AzCore/Serialization/EditContextConstants.inl>
#include <LocalUser/LocalUserRequestBus.h>
#include <SaveData/SaveDataRequestBus.h>

#include "cgdc2022SystemComponent.h"

namespace cgdc2022
{
    class cgdc2022NotificationBusBehaviorHandler
        : public cgdc2022NotificationBus::Handler
        , public AZ::BehaviorEBusHandler
    {
    public:
        ////////////////////////////////////////////////////////////////////////////////////////////
        AZ_EBUS_BEHAVIOR_BINDER(cgdc2022NotificationBusBehaviorHandler, "{CE11195D-BDD2-46A1-92CF-5714E0973DA1}", AZ::SystemAllocator
            , OnLevelLoaded
        );

        ////////////////////////////////////////////////////////////////////////////////////////////
        void OnLevelLoaded(LevelData levelData) override
        {
            Call(FN_OnLevelLoaded, levelData);
        }
    };

    void cgdc2022SystemComponent::Reflect(AZ::ReflectContext* context)
    {
        LevelData::Reflect(context);

        if (AZ::SerializeContext* serialize = azrtti_cast<AZ::SerializeContext*>(context))
        {
            serialize->Class<cgdc2022SystemComponent, AZ::Component>()
                ->Version(0)
                ;

            if (AZ::EditContext* ec = serialize->GetEditContext())
            {
                ec->Class<cgdc2022SystemComponent>("cgdc2022", "[Description of functionality provided by this System Component]")
                    ->ClassElement(AZ::Edit::ClassElements::EditorData, "")
                        ->Attribute(AZ::Edit::Attributes::AppearsInAddComponentMenu, AZ_CRC("System"))
                        ->Attribute(AZ::Edit::Attributes::AutoExpand, true)
                    ;
            }
        }


        AZ::BehaviorContext* behaviorContext = azrtti_cast<AZ::BehaviorContext*>(context);
        if (behaviorContext)
        {
            behaviorContext->EBus<cgdc2022RequestBus>("GameRequestBus")
                ->Event("LoadLevel", &cgdc2022RequestBus::Events::LoadLevel)
                ->Event("SaveLevel", &cgdc2022RequestBus::Events::SaveLevel);

            behaviorContext->EBus<cgdc2022NotificationBus>("GameNotificationBus")
                ->Handler<cgdc2022NotificationBusBehaviorHandler>();
        }
    }

    void cgdc2022SystemComponent::GetProvidedServices(AZ::ComponentDescriptor::DependencyArrayType& provided)
    {
        provided.push_back(AZ_CRC("cgdc2022Service"));
    }

    void cgdc2022SystemComponent::GetIncompatibleServices(AZ::ComponentDescriptor::DependencyArrayType& incompatible)
    {
        incompatible.push_back(AZ_CRC("cgdc2022Service"));
    }

    void cgdc2022SystemComponent::GetRequiredServices([[maybe_unused]] AZ::ComponentDescriptor::DependencyArrayType& required)
    {
    }

    void cgdc2022SystemComponent::GetDependentServices([[maybe_unused]] AZ::ComponentDescriptor::DependencyArrayType& dependent)
    {
    }

    cgdc2022SystemComponent::cgdc2022SystemComponent()
    {
        if (cgdc2022Interface::Get() == nullptr)
        {
            cgdc2022Interface::Register(this);
        }
    }

    cgdc2022SystemComponent::~cgdc2022SystemComponent()
    {
        if (cgdc2022Interface::Get() == this)
        {
            cgdc2022Interface::Unregister(this);
        }
    }

    void cgdc2022SystemComponent::Init()
    {
    }

    void cgdc2022SystemComponent::Activate()
    {
        cgdc2022RequestBus::Handler::BusConnect();

        m_levelData = AZStd::make_shared<LevelData>();
    }

    void cgdc2022SystemComponent::Deactivate()
    {
        cgdc2022RequestBus::Handler::BusDisconnect();
    }

    void cgdc2022SystemComponent::LoadLevel(const AZStd::string& levelName)
    {
        SaveData::SaveDataRequests::SaveOrLoadObjectParams<LevelData> loadObjectParams;
        loadObjectParams.serializableObject = m_levelData;
        loadObjectParams.dataBufferName = AZStd::string("LevelData_").append(levelName);
        loadObjectParams.localUserId = LocalUser::LocalUserRequests::GetPrimaryLocalUserId();
        loadObjectParams.callback = [](const SaveData::SaveDataRequests::SaveOrLoadObjectParams<LevelData>& params,
                                       [[maybe_unused]] SaveData::SaveDataNotifications::Result result)
        {
            AZ_Warning("LoadLevel", false, "In callback and result is %s", result == SaveData::SaveDataNotifications::Result::Success ? "Success" : "Error");
            if (params.serializableObject)
            {
                cgdc2022NotificationBus::Broadcast(&cgdc2022NotificationBus::Events::OnLevelLoaded, *params.serializableObject);
            }
        };
        SaveData::SaveDataRequests::LoadObject(loadObjectParams);
    }

    void cgdc2022SystemComponent::SaveLevel(const AZStd::string& levelName, const LevelData& levelData)
    {
        SaveData::SaveDataRequests::SaveOrLoadObjectParams<LevelData> saveObjectParams;
        saveObjectParams.serializableObject = AZStd::make_shared<LevelData>(levelData);
        saveObjectParams.dataBufferName = AZStd::string("LevelData_").append(levelName);
        saveObjectParams.localUserId = LocalUser::LocalUserRequests::GetPrimaryLocalUserId();
        SaveData::SaveDataRequests::SaveObject(saveObjectParams);
    }
}
