{-# LANGUAGE DeriveAnyClass    #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE OverloadedStrings #-}
module Elm.Analyse
    ( loadModuleDependencies
    , getNodeAndEdgeCounts
    ) where

import Data.Aeson (FromJSON, eitherDecodeFileStrict')
import Data.Graph.Inductive.Graph (mkGraph, order, size)
import Data.IntSet (IntSet)
import Data.Map.Strict (Map)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import GHC.Generics (Generic)
import Graph.Types (ModuleDependencies (..), mkNodeLabel)
import System.Exit (die)
import Data.Bifunctor (first)

import qualified Data.IntSet as Set
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text

-- input is file X obtained by running "elm-analyse --format json > X"
loadModuleDependencies :: FilePath -> IO ModuleDependencies
loadModuleDependencies resultsFile = do
    maybeAnalysisResult <- eitherDecodeFileStrict' resultsFile
    case maybeAnalysisResult of
        Left err -> die $ "Failed to load analysis result from file : " <> resultsFile <>
                         "\nThe error was: " <> err
        Right analysisResult -> return $ toGraph analysisResult

newtype AnalysisResult = AnalysisResult
    { modules :: Modules
    } deriving (Eq, Show, Ord, Generic, FromJSON)

data Modules = Modules
    { projectModules :: [Module] -- ^ modules of currently analyzed elm.json EXCLUDING dependencies
    , dependencies   :: [(Module, Module)] -- module dependencies INCLUDING modules from external deps
    } deriving (Eq, Show, Ord, Generic, FromJSON)

newtype Module = Module [Text]
     deriving (Eq, Show, Ord, Generic, FromJSON)

moduleName :: Module -> Text
moduleName (Module xs) = Text.intercalate "." xs

toGraph :: AnalysisResult -> ModuleDependencies
toGraph AnalysisResult{modules} =
    ModuleDependencies { depGraph = mkGraph nodes edges }
  where
    nameToIdMap = foldr
        (\(module1, module2) map0 ->
            let map1 = insertUniqueId module1 (Map.size map0) map0
            in         insertUniqueId module2 (Map.size map1) map1
        ) Map.empty (dependencies modules)

    appModuleIds :: IntSet
    appModuleIds = Set.fromList $ mapMaybe (\module_ -> Map.lookup module_ nameToIdMap) (projectModules modules)

    nodes = (\(module_, moduleId) -> ( moduleId
                                     , mkNodeLabel
                                         (moduleName module_)
                                         (Map.lookup module_ moduleToPackage)
                                         (moduleId `Set.member` appModuleIds)
                                     )) <$> Map.toList nameToIdMap

    edges = (\(module1, module2) -> ( nameToIdMap Map.! module1
                                    , nameToIdMap Map.! module2
                                    , ()
                                    )) <$> dependencies modules

insertUniqueId :: Ord k => k -> v -> Map k v -> Map k v
insertUniqueId = Map.insertWith (\_newVal oldVal -> oldVal)

getNodeAndEdgeCounts :: ModuleDependencies -> (Int, Int)
getNodeAndEdgeCounts ModuleDependencies{depGraph} =
    (order depGraph, size depGraph)


-- TODO load this dynamically instead of hardcoding it
moduleToPackage :: Map Module Text
moduleToPackage = Map.fromList $ fmap (first (Module . Text.splitOn "."))
    [ ("Analytics","_share")
    , ("Analytics.AudienceBuilder","_share")
    , ("Analytics.Calculations","_share")
    , ("Analytics.ChartBuilder","_share")
    , ("Analytics.Common","_share")
    , ("Analytics.Error","_share")
    , ("Analytics.Export","_share")
    , ("Analytics.Filters","_share")
    , ("Analytics.Home","_share")
    , ("Analytics.Menu","_share")
    , ("Analytics.Onboarding","_share")
    , ("Analytics.QueryBuilder","query-builder")
    , ("Analytics.Search","_share")
    , ("Analytics.TV","_share")
    , ("Analytics.Upsell","_share")
    , ("Analytics.UserSettings","_share")
    , ("App","app-monolithic")
    , ("AudienceBuilder.QueryTheData","audience-builder")
    , ("Campaigns","gwiq")
    , ("Campaigns.Overview","gwiq")
    , ("CarouselSlider.Main","products")
    , ("Cart","settings")
    , ("ChartBuilder","chart-builder")
    , ("ChartBuilder.Charts","chart-builder")
    , ("ChartBuilder.ChartsTest","chart-builder")
    , ("ChartBuilder.DataCache","chart-builder")
    , ("ChartBuilder.Header","chart-builder")
    , ("ChartBuilder.Metric","chart-builder")
    , ("ChartBuilder.Utils","chart-builder")
    , ("ChartBuilderHeaderComponent","components")
    , ("Checkbox","_share")
    , ("Config","_share")
    , ("Config.Main","_share")
    , ("Constants","_share")
    , ("CoolTip","_share")
    , ("Cotws.Main","products")
    , ("CrossTab","query-builder")
    , ("CrossTabTest","query-builder")
    , ("Dashboard.Main","dashboards")
    , ("Dashboard.Show","dashboards")
    , ("Dashboard.StatCard.Main","dashboards")
    , ("Data.Audience.Expression","_share")
    , ("Data.Calc.AudienceIntersect","query-builder")
    , ("Data.Calc.AudienceIntersect.Export","query-builder")
    , ("Data.Calc.Core","chart-builder")
    , ("Data.Calc.Core.Export","chart-builder")
    , ("Data.Campaign","gwiq")
    , ("Data.Core","_share")
    , ("Data.CoreTest","_share")
    , ("Data.DataPermissions","_share")
    , ("Data.DataPermissionsTest","_share")
    , ("Data.Error","_share")
    , ("Data.Labels","_share")
    , ("Data.Labels.Category","_share")
    , ("Data.Labels.Fulltext","_share")
    , ("Data.Labels.Question","_share")
    , ("Data.Labels.QuestionTest","_share")
    , ("Data.LabelsTest","_share")
    , ("Data.Products","products")
    , ("Data.Products.Search","products")
    , ("Data.QueryBuilder","query-builder")
    , ("Data.SavedQuery.Segmentation","chart-builder")
    , ("Data.SimpleREST","_share")
    , ("Data.SimpleRESTTest","_share")
    , ("Data.TV","tv-elm")
    , ("Data.TVTest","tv-elm")
    , ("Data.Upsell","_share")
    , ("Data.User","_share")
    , ("Data.User.CurrentUser","_share")
    , ("Data.UserTest","_share")
    , ("Data.Users","settings")
    , ("Data.UsersTest","_share")
    , ("Dialog","_share")
    , ("Dialog.Alert","_share")
    , ("Dialog.Confirm","_share")
    , ("Dialog.Error","_share")
    , ("DragEvents","_share")
    , ("DropDownMenu.Main","chart-builder")
    , ("ElmImageBox.Main","products")
    , ("Ember","_share")
    , ("Entry","app-monolithic")
    , ("Error.NotFound","app-monolithic")
    , ("Factory.Bundles","_factories")
    , ("Factory.Datapoint","_factories")
    , ("Factory.Flags","_factories")
    , ("Factory.Question","_factories")
    , ("Factory.User","_factories")
    , ("Factory.Wave","_factories")
    , ("Filters.Audiences","_share")
    , ("Filters.AudiencesPanel","_share")
    , ("Filters.AudiencesTest","_share")
    , ("Filters.Features","_share")
    , ("Filters.Locations","_share")
    , ("Filters.Main","_share")
    , ("Filters.Splitters","_share")
    , ("Filters.TVChannels","_share")
    , ("Filters.UpsellBanner","_share")
    , ("Filters.Waves","_share")
    , ("FiltersComponent","components")
    , ("FullscreenSearch","fullscreen-search")
    , ("FullscreenSearchTest","app-monolithic")
    , ("Grid","dashboards")
    , ("Grid.Types","dashboards")
    , ("Grid.Utils","dashboards")
    , ("Home","app-monolithic")
    , ("HomescreenComponent","components")
    , ("Icons","_share")
    , ("Icons.FontAwesome","_share")
    , ("Icons.Gwi","_share")
    , ("Infographics.Main","products")
    , ("JimmySorter","_share")
    , ("Json.Extra","_share")
    , ("LeavePageConfirm","_share")
    , ("Legacy","_share")
    , ("Lib.GridTest","dashboards")
    , ("Lib.Notification.QueueTest","_share")
    , ("Lib.PluralRulesTest","_share")
    , ("Main","components")
    , ("Menu","app-monolithic")
    , ("Menu.ChartBuilder","app-monolithic")
    , ("Menu.Cotws","app-monolithic")
    , ("Menu.Dashboards","app-monolithic")
    , ("Menu.Infographics","app-monolithic")
    , ("Menu.Loading","app-monolithic")
    , ("Menu.Reports","app-monolithic")
    , ("Menu.UpsellBanner","app-monolithic")
    , ("MenuComponent","components")
    , ("Notification","_share")
    , ("Notification.Queue","_share")
    , ("Notifications","_share")
    , ("Onboarding","app-monolithic")
    , ("Onboarding.Data","app-monolithic")
    , ("Overview","_share")
    , ("Palette","_share")
    , ("Permissions","_share")
    , ("PermissionsTest","_share")
    , ("PluralRules","_share")
    , ("PluralRules.En","_share")
    , ("PptxExportComponent","components")
    , ("QuantifierClass","_share")
    , ("QueryBuilder","query-builder")
    , ("QueryBuilder.AudiencesGroup","query-builder")
    , ("QueryBuilder.Browser","query-builder")
    , ("QueryBuilder.Browser.Audiences","query-builder")
    , ("QueryBuilder.Browser.Datapoints","query-builder")
    , ("QueryBuilder.DatapointsGroup","query-builder")
    , ("QueryBuilder.Detail","query-builder")
    , ("QueryBuilder.Detail.BaseView","query-builder")
    , ("QueryBuilder.Detail.BrowserView","query-builder")
    , ("QueryBuilder.Detail.Common","query-builder")
    , ("QueryBuilder.Detail.ModalView","query-builder")
    , ("QueryBuilder.Detail.TableHeaderView","query-builder")
    , ("QueryBuilder.Detail.TableView","query-builder")
    , ("QueryBuilder.DetailTest","query-builder")
    , ("QueryBuilder.Header","query-builder")
    , ("QueryBuilder.Label","query-builder")
    , ("QueryBuilder.List","query-builder")
    , ("QueryBuilder.Metric","query-builder")
    , ("QueryBuilder.MetricsTransposition","query-builder")
    , ("QueryBuilder.Modal","query-builder")
    , ("QueryBuilder.Modal.Detail","query-builder")
    , ("QueryBuilder.Modal.Locations","query-builder")
    , ("QueryBuilder.Modal.Waves","query-builder")
    , ("QueryBuilder.MoreOptions","query-builder")
    , ("QueryBuilder.ProjectName","query-builder")
    , ("QueryBuilder.ProjectNotes","query-builder")
    , ("QueryBuilder.Search","query-builder")
    , ("QueryBuilder.WavesUtils","query-builder")
    , ("QueryBuilderComponent","components")
    , ("Reports.Main","products")
    , ("Router","_share")
    , ("Router.QueryBuilder","_share")
    , ("RouterTest","_share")
    , ("Scroll","_share")
    , ("Search","_share")
    , ("SearchComponent","components")
    , ("Spinner.Main","_share")
    , ("StatCard","components")
    , ("StatCardComponent","components")
    , ("Store","app-monolithic")
    , ("Store.Campaigns","_share")
    , ("Store.Core","_share")
    , ("Store.Products","_share")
    , ("Store.QueryBuilder","query-builder")
    , ("Store.TV","_share")
    , ("Store.UserSettings","_share")
    , ("Store.Utils","_share")
    , ("String.GWIExtra","_share")
    , ("TV","tv-elm")
    , ("TV.Edit","tv-elm")
    , ("TV.List","tv-elm")
    , ("TV.Results","tv-elm")
    , ("TV.Results.ParameterSections","tv-elm")
    , ("TaggedList.Main","products")
    , ("Time.Format","_share")
    , ("TimeSchedule","_share")
    , ("Tooltip.Main","_share")
    , ("Tuple.Extra","_share")
    , ("TvStudy","tv-study")
    , ("Upsell.Dialog","_share")
    , ("UserSettings.Billing","settings")
    , ("UserSettings.Billing.ActiveBundles","settings")
    , ("UserSettings.Billing.PaymentDetails","settings")
    , ("UserSettings.Billing.PaymentDetailsTest","settings")
    , ("UserSettings.Billing.Receipts","settings")
    , ("UserSettings.Bundles","settings")
    , ("UserSettings.Bundles.Cart","settings")
    , ("UserSettings.Bundles.CartTest","settings")
    , ("UserSettings.BundlesTest","settings")
    , ("UserSettings.BuyBundles","settings")
    , ("UserSettings.BuyBundlesTest","settings")
    , ("UserSettings.Main","settings")
    , ("UserSettings.Organisation","settings")
    , ("UserSettings.Overview","settings")
    , ("UserSettings.Security","settings")
    , ("UserSettingsComponent","components")
    , ("Utils","components")
    , ("Utils.ActiveAudiences","_share")
    , ("Utils.ActiveFilters","_share")
    , ("Utils.ActiveSegments","_share")
    , ("Utils.Audience","_share")
    , ("Utils.Decoder","_share")
    , ("Utils.Encode","_share")
    , ("Utils.ErrorHandling","_share")
    , ("Utils.Export","_share")
    , ("Utils.FormatNumber","_share")
    , ("Utils.FormatNumberTest","_share")
    , ("Utils.HelpCenter","_share")
    , ("Utils.Helpers","_share")
    , ("Utils.Http","_share")
    , ("Utils.Intercom","_share")
    , ("Utils.ListSort","_share")
    , ("Utils.ListSortTest","_share")
    , ("Utils.Price","_share")
    , ("Utils.PriceTest","_share")
    , ("Utils.SelectWithOther","_share")
    , ("Xtag","_share")
    , ("YouTube","_share")
    ]
