
#pragma once

#include <AzCore/Component/Component.h>

#include <cgdc2022/cgdc2022Bus.h>

namespace cgdc2022
{
    class cgdc2022SystemComponent
        : public AZ::Component
        , protected cgdc2022RequestBus::Handler
    {
    public:
        AZ_COMPONENT(cgdc2022SystemComponent, "{A24A3B5C-743F-4946-A533-8B0A31367DFF}");

        static void Reflect(AZ::ReflectContext* context);

        static void GetProvidedServices(AZ::ComponentDescriptor::DependencyArrayType& provided);
        static void GetIncompatibleServices(AZ::ComponentDescriptor::DependencyArrayType& incompatible);
        static void GetRequiredServices(AZ::ComponentDescriptor::DependencyArrayType& required);
        static void GetDependentServices(AZ::ComponentDescriptor::DependencyArrayType& dependent);

        cgdc2022SystemComponent();
        ~cgdc2022SystemComponent();

    protected:
        // cgdc2022RequestBus interface implementation
        void LoadLevel(const AZStd::string& levelName) override;
        void SaveLevel(const AZStd::string& levelName, const LevelData& levelData) override;

        // AZ::Component interface implementation
        void Init() override;
        void Activate() override;
        void Deactivate() override;
    };
}
